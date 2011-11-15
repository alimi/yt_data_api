require "yt_data_api/version"
require 'net/https'
require 'open-uri'
require 'rss'
require 'xml'

module YtDataApi
  class YtDataApiClient
    def initialize(user_id, user_pswd, dev_key)
      post_response = client_login(user_id, user_pswd, dev_key)
      
      if(post_response.code != "200")
        raise "Error while authenticating #{user_id} - #{post_response.code}: #{post_response.message}"
      end
    end

    def create_playlist(playlist_name)
      headers = {"Content-Type" => "application/atom+xml", 
                 "Authorization" => "GoogleLogin auth=#{@client_auth_key}", 
                 "X-GData-Key" => @dev_auth_key,
                 "GData-Version" => "2"}
		
      new_row = "<?xml version='1.0' encoding='UTF-8'?>" + 
                "<entry xmlns='http://www.w3.org/2005/Atom' " + 
                "xmlns:yt='http://gdata.youtube.com/schemas/2007'>" +
                "<title type='text'>#{playlist_name}</title><summary></summary></entry>"

      headers["Content-Length"] = new_row.bytesize.to_s

      uri = URI.parse("http://gdata.youtube.com/feeds/api/users/default/playlists")
      http = Net::HTTP.new(uri.host, uri.port)
      
      post_response = http.post(uri.path, new_row, headers)
      post_response_content = parse_atom_xml(post_response)
      post_response_entry = post_response_content.root.find_first('yt:playlistId')
      playlist_id = post_response_entry.content
      
      return post_response, playlist_id
    end
    
    def get_playlist_id(playlist_name)
      headers = {"Content-Type" => "application/x-www-form-urlencoded", 
                 "Authorization" => "GoogleLogin auth=#{@client_auth_key}", 
                 "X-GData-Key" => @dev_auth_key}	
		
      uri = URI.parse("http://gdata.youtube.com/feeds/api/users/default/playlists?v=2")

      playlists_feed = Net::HTTP.start(uri.host, uri.port){|http|
        http.get(uri.path, headers)
      }
      
      playlists_content = parse_atom_xml(playlists_feed)
      playlists_entries = playlists_content.root.find('atom:entry')

      playlists_entries.each do |entry|
        if(entry.find_first('atom:title').content.eql?(playlist_name))
          return entry.find_first('yt:playlistId').content
        end
      end
		
      return nil
    end
    
    def get_video_ids(search_query, count = 1)
      query_uri = URI.parse("http://gdata.youtube.com/feeds/api/videos?q=#{search_query}&max-results=#{count}")
      rss_query_result = parse_rss(query_uri)
      video_ids = []
      
      rss_query_result.items.each do |item|
        video_id = item.id.to_s[/<id>http:\/\/(.*\/)(.*)<\/id>/, 2]
        return video_id if count == 1
        video_ids << video_id
      end

      if(video_ids.empty?)
        nil
      else
        video_ids
      end
    end
    
    def add_video_to_playlist(video_id, playlist_id)
      headers = {"Content-Type" => "application/atom+xml", 
                 "Authorization" => "GoogleLogin auth=#{@client_auth_key}", 
                 "X-GData-Key" => @dev_auth_key,
                 "GData-Version" => "2"}		

      new_row = "<?xml version='1.0' encoding='UTF-8'?>" + 
                "<entry xmlns='http://www.w3.org/2005/Atom' " + 
                "xmlns:yt='http://gdata.youtube.com/schemas/2007'>" +
                "<id>#{video_id}</id></entry>"

      headers["Content-Length"] = new_row.bytesize.to_s

      uri = URI.parse("http://gdata.youtube.com/feeds/api/playlists/#{playlist_id}")
      http = Net::HTTP.new(uri.host, uri.port)

      post_response = http.post(uri.path, new_row, headers)
    end
    
    def add_videos_to_playlist(video_ids, playlist_id)
      failed_to_add = []
      
      video_ids.each_with_index do |video_id, index|
        post_response = add_video_to_playlist(video_id, playlist_id)
        
        if(post_response.code == "403")
          sleep(30)
          post_repsonse = add_video_to_playlist(video_id, playlist_id)
        end
        
        if(post_response.code != "201")
          failed_to_add << "#{index + 1},#{video_id},#{post_response.code}"
        end
      end
      
      if(failed_to_add.empty?)
        "201"
      else
        failed_to_add
      end
    end

    def get_client_playlist_entries(playlist_id)
      headers = {"Content-Type" => "application/x-www-form-urlencoded", 
                 "Authorization" => "GoogleLogin auth=#{@client_auth_key}", 
                 "X-GData-Key" => @dev_auth_key}	
		
      uri = URI.parse("http://gdata.youtube.com/feeds/api/playlists/#{playlist_id}?v=2")

      playlist_entries_feed = Net::HTTP.start(uri.host, uri.port){|http|
        http.get(uri.path, headers)
      }

      playlist_entries_content = parse_atom_xml(playlist_entries_feed)
      playlist_entries = playlist_entries_content.root.find('atom:entry')

      playlist_entries_ids = []

      playlist_entries.each do |entry|
        entry_id = entry.find_first('atom:id')
        playlist_entry = 
          entry_id.content[/http:\/\/.*\/(.+)/, 1]
        playlist_entries_ids << playlist_entry
      end
		
      playlist_entries_ids

    end

    def empty_playlist(playlist_id)
      headers = {"Content-Type" => "application/atom+xml", 
                 "Authorization" => "GoogleLogin auth=#{@client_auth_key}", 
                 "X-GData-Key" => @dev_auth_key,
                 "GData-Version" => "2"}

      playlist_entries = self.get_client_playlist_entries(playlist_id)

      playlist_entries.each do |playlist_entry|
        uri = URI.parse("http://gdata.youtube.com/feeds/api/playlists/#{playlist_id}/#{playlist_entry}")
        http = Net::HTTP.new(uri.host, uri.port)

        delete_response = http.delete(uri.path, headers)
    
        if(delete_response.code != "200")
          raise "#{playlist_entry} not deleted from #{@playlist_id} - #{delete_response.code}"
        end
      end

      self.get_client_playlist_entries(playlist_id).empty?
    end

    def delete_playlist(playlist_id)
      headers = {"Content-Type" => "application/atom+xml", 
                 "Authorization" => "GoogleLogin auth=#{@client_auth_key}", 
                 "X-GData-Key" => @dev_auth_key,
                 "GData-Version" => "2"}

      uri = URI.parse("http://gdata.youtube.com/feeds/api/users/#{@client_user_id}/playlists/#{playlist_id}")
      http = Net::HTTP.new(uri.host, uri.port)

      delete_response = http.delete(uri.path, headers)
    
      if(delete_response.code != "200")
        raise "#{playlist_id} not deleted for #{@client_user_id} - #{delete_response.code}"
      end

      delete_response.code
    end
    
    private
      #Use Ruby RSS Parser to return parseable info from RSS feed
      def parse_rss(rss_feed)
        rss_content = ""

        #Get feed information
        open (rss_feed) do |f|
          rss_content = f.read
        end

        RSS::Parser.parse(rss_content, false)
      end
      
      def parse_atom_xml(xml)
        source = XML::Parser.string(xml.body)
        content = source.parse
        content.root.namespaces.default_prefix = 'atom'
        content
      end
      
      def http_post_ssl(url, data, headers)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        http.post(uri.path, data, headers)
      end
      
      def client_login(user_id, user_pswd, dev_key)      
        post_url = "https://www.google.com/accounts/ClientLogin"
        data = "Email=#{user_id}&Passwd=#{user_pswd}&service=youtube&source=YtDataApi"
        headers = {"Content-Type" => "application/x-www-form-urlencoded"}

        post_response, data = http_post_ssl(post_url, data, headers)

        if(post_response.code != "200")
          post_response
        else
          @client_user_id = user_id
          @client_auth_key = data[/Auth=(.*)/, 1]
          @dev_auth_key = "key=" + dev_key
          post_response
        end
      end
  end
end

require "yt_data_api/version"
require 'net/https'
require 'open-uri'
require 'rss'
require 'xml'

module YtDataApi
  class YtDataApiClient
    def initialize(user_id, user_pswd, dev_key)
      self.client_login(user_id, user_pswd, dev_key)
    end

    def client_login(user_id, user_pswd, dev_key)
      http = Net::HTTP.new("www.google.com", 443)
      http.use_ssl = true
      path = "/accounts/ClientLogin"

      data = "Email=#{user_id}&Passwd=#{user_pswd}&service=youtube&source=Test"
      headers = {"Content-Type" => "application/x-www-form-urlencoded"}

      response, data = http.post(path, data, headers)

      if(response.code != "200")
        raise "Error while authenticating YouTube user - #{response.code}"
      end

      @client_user_id = user_id
      @client_auth_key = data[/Auth=(.*)/, 1]
      @dev_auth_key = "key=" + dev_key
    end

    def get_video_id(search_query)
      query_uri = URI.parse("http://gdata.youtube.com/feeds/api/videos?q=#{search_query}&max-results=1")
      rss_query_result = parse_rss(query_uri)

      rss_query_result.items.each do |item|
        return item.id.to_s[/<id>http:\/\/(.*\/)(.*)<\/id>/, 2]
      end

      return nil
    end

    def get_client_playlist_id(playlist_name)
      headers = {"Content-Type" => "application/x-www-form-urlencoded", 
                 "Authorization" => "GoogleLogin auth=#{@client_auth_key}", 
                 "X-GData-Key" => @dev_auth_key}	
		
      uri = URI.parse("http://gdata.youtube.com/feeds/api/users/default/playlists?v=2")

      xml_client_playlists = Net::HTTP.start(uri.host, uri.port){|http|
        http.get(uri.path, headers)
      }

      #Parse xml of client's playlists
      source = XML::Parser.string(xml_client_playlists.body)
      content = source.parse
      content.root.namespaces.default_prefix = 'atom'

      entries = content.root.find('atom:entry')
		
      #Get playlist id
      entries.each do |entry|
        if(entry.find_first('atom:title').content.eql?(playlist_name))
          feedlink = entry.find_first('gd:feedLink').attributes["href"]
          return feedlink[/http:\/\/gdata.youtube.com\/feeds\/api\/playlists\/(.+)/, 1]
        end
      end
		
      return nil
    end

    def get_client_playlist_entries(playlist_id)
      headers = {"Content-Type" => "application/x-www-form-urlencoded", 
                 "Authorization" => "GoogleLogin auth=#{@client_auth_key}", 
                 "X-GData-Key" => @dev_auth_key}	
		
      uri = URI.parse("http://gdata.youtube.com/feeds/api/playlists/#{playlist_id}?v=2")

      xml_client_playlist_videos = Net::HTTP.start(uri.host, uri.port){|http|
        http.get(uri.path, headers)
      }

      source = XML::Parser.string(xml_client_playlist_videos.body)
      content = source.parse
      content.root.namespaces.default_prefix = 'atom'

      entries = content.root.find('atom:entry')

      playlist_entries = []

      entries.each do |entry|
        entry_id = entry.find_first('atom:id')
        playlist_entry = 
          entry_id.content[/http:\/\/.*\/(.+)/, 1]
        playlist_entries << playlist_entry
      end
		
      playlist_entries

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

      if(post_response.code != "201")
        raise "Error while adding #{video_id} to #{playlist_id} - #{post_response.code}"
      end

      post_response.code
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

      if(post_response.code != "201")
        raise "Error while creating #{playlist_name} - #{post_response.code}"
      end

      post_response.code
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
  end
end

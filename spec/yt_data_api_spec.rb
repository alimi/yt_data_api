require 'spec_helper'

describe "YtDataApi::YtDataApiClient" do
  it "should create a new instance using ClientLogin authentication" do
    YtDataApi::YtDataApiClient.new(ENV['YT_USER'], ENV['YT_USER_PSWD'], ENV['YT_DEV_AUTH_KEY'])
  end

  it "should not create a new instance without valid credentials for ClientLogin Authentication" do
    lambda{ YtDataApi::YtDataApiClient.new("trash", "trash", "trash") }.should raise_error
  end 

  describe "authenticated" do
    before(:each) do
      @client = YtDataApi::YtDataApiClient.new(ENV['YT_USER'], ENV['YT_USER_PSWD'], ENV['YT_DEV_AUTH_KEY'])
      @create_response, @playlist_id = @client.create_playlist("test_one")
    end

    it "should create a client's playlist" do
      @create_response.code.should == "201"
    end

    it "should get a client's playlist id given the playlist's name" do
      playlist_id = @client.get_playlist_id("test_one")
      playlist_id.should == @playlist_id
    end
    
    it "should return nil if the playlist id cannot be found given playlist name" do
      playlist_id = @client.get_playlist_id("trash")
      playlist_id.should == nil
    end

    it "should get one video id given a query string" do
      query = "vampire-weekend-giving-up-the-gun"
      video_id = @client.get_video_ids(query)
      video_id.should == "bccKotFwzoY"
    end
    
    it "should get multiple video ids given a query string and count" do
      query = "vampire-weekend-giving-up-the-gun"
      video_ids = @client.get_video_ids(query, 10)
      video_ids.size.should == 10
    end
    
    it "should return nil if no videos are found for given query" do
      query = ","
      video_id = @client.get_video_ids(query)
      video_id.should == nil
    end

    it "should add a video to a client's playlist" do
      video_id = "bccKotFwzoY"
      post_response = @client.add_video_to_playlist(video_id, @playlist_id)
      post_response.code.should == "201"
    end
    
    it "should add multiple videos (less than 50) to a client's playlist" do
      video_ids = []
      5.times do
        video_ids << "bccKotFwzoY"
      end
      
      post_response = @client.add_videos_to_playlist(video_ids, @playlist_id)
      post_response.should == "201"
    end
    
    it "should return an array of videos that could not be added to the client's playlist" do
      video_ids = %w{ bccKotFwzoY trash trash bccKotFwzoY trash }
      
      post_response = @client.add_videos_to_playlist(video_ids, @playlist_id)
      array = post_response.map{|entry| entry.split(",")[1] }
      array.should == %w{ trash trash trash }
    end
    
    it "should add multiple videos (more than 50) to a playlist" do
      video_ids = []
      100.times do
        video_ids << "bccKotFwzoY"
      end
      
      post_response = @client.add_videos_to_playlist(video_ids, @playlist_id)
      post_response.should == "201"
    end

    it "should remove all videos from a client's playlist" do
      3.times do
        @client.add_video_to_playlist("bccKotFwzoY", @playlist_id)
      end
     
      empty_playlist = @client.empty_playlist(@playlist_id)
      empty_playlist.should == true
    end

    it "should delete a client's playlist" do
      delete_response = @client.delete_playlist(@playlist_id)
      delete_response.should == "200"
    end

    after(:each) do
      playlist = @client.get_playlist_id("test_one")
      @client.delete_playlist(@playlist_id) unless playlist.nil?
    end
  end
end
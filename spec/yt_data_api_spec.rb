require 'spec_helper'

describe "YtDataApi::YtDataApiClient" do
  it "should create a new instance using ClientLogin authentication" do
    YtDataApi::YtDataApiClient.new(ENV['YT_USER'], ENV['YT_USER_PSWD'], ENV['YT_DEV_AUTH_KEY'])
  end

  it "should not create a new instance without credentials for ClientLogin Authentication" do
    lambda{ YtDataApi::YtDataApiClient.new }.should raise_error ArgumentError
  end

  it "should not create a new instance without valid credentials for ClientLogin Authentication" do
    lambda{ YtDataApi::YtDataApiClient.new("trash", "trash", "trash") }.should raise_error
  end 

  describe "authenticated" do
    before(:each) do
      @client = YtDataApi::YtDataApiClient.new(ENV['YT_USER'], ENV['YT_USER_PSWD'], ENV['YT_DEV_AUTH_KEY'])
      @create_response = @client.create_playlist("test_one")
      @playlist_id = @client.get_client_playlist_id("test_one")
    end

    it "should create a client's playlist" do
      @create_response.should == "201"
    end

    it "should get a client's playlist id given the playlist's name" do
     @playlist_id.should_not be nil
    end

    it "should get a video id given a query string" do
      query = "vampire-weekend-giving-up-the-gun"
      video_id = @client.get_video_id(query)
      video_id.should == "bccKotFwzoY"
    end

    it "should add a video to a client's playlist" do
      video_id = "bccKotFwzoY"
      post_response = @client.add_video_to_playlist(video_id, @playlist_id)
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
      playlist = @client.get_client_playlist_id("test_one")
      @client.delete_playlist(@playlist_id) unless playlist.nil?
    end
  end
end
#Yt_Data_Api

yt_data_api adds functionality to access elements of the YouTube Data API.  This was created as a learning tool.  Check out youtube_it for more functionality, https://github.com/kylejginavan/youtube_it.

#Usage

First, create a new client object passing YouTube user credentials.  Note you will have to acquire a developer key from YouTube, http://code.google.com/apis/youtube/2.0/developers_guide_protocol.html#Developer_Key.

`client = YtDataApi::YtDataApiClient.new(YOUTUBE_USER_ID, YOUTUBE_USER_PSWD, YOUTUBE_DEV_KEY)`

Then, call functions on the client object to access the YouTube Data API.

##Create a playlist and get it's id
`client.create_playlist("test")`
`playlist_id = client.get_client_playlist_id("test")`

##Delete a playlist
`client.delete_playlist(playlist_id)`

##Get a video id given a query
Note spaces were replaced with '+'
`video_id = client.get_video_id("Otis+Kanye+West")`

##Add video to client playlist
`client.add_video_to_playlist(video_id, playlist_id)`

#TODO
- Add more functionality
# bugs that im aware of
1. sometimes the PlayPause button is synced correctly, i have to add onPlay, onPause, onResume
   listeners to it regardless of them existing in it's parent widget
2. need a better way to play songs that dont exist locally but remotely than just add them to the
   queue once they're downloaded..
3. the Data section is yet to be built, tho data collection code is (i think) finished
3. sometimes when downloading multiple songs at once, the image for the current song doesnt get added to the musicwidget player coorectly
4. i should add an option to prioritize downloads and another to download all songs at once, but that would require me to save downloading progress and save it when the app is exited
5. i need to check for corrupted local files, if an audio file is corrupted, the applications goes crazy and the music monitor starts spamming the database with alot of playbacks
6. the image and audio download functions dont check to see if the file with the id is already present, but they should, i should atleast add an option to the function to allow checking locally for files first.
7. i have a bunch of constants like BACKGROUND_COLOR spreaded in the project files, i should either make a constants.dart and put them there or figure out a better way to theme the entire app with same colors
8. in the database provider, i many times copied the same code that downloads images and audio for songs and albums and so on, i should make a function called downloadFile and use that to prevent code duplication
9. right after the app starts it starts downloading metadata from server and waits for download to complete to display any items, this is bad, but not a problem for me atm because im using this app in a LAN
10. i should rebuild songlist widgets when the song changes to display the green playing arrow on the newly playing song
11. the code contains alot of hardcoded values, even the password and username are hardcoded and there is no way to change them without editing the code, but im running the service locally so who cares atm.
12. currently when a song is liked, a post request is made indicating that, and when the metadata is fetched again im checking whether the liked_song already exists in the local database before adding it because i add it right after i liked the song to the local database, shouldnt be done like that, its not good to keep checking if a song id exists in the playlists row of the 'liked songs' playlist before trying to insert a new one, the data the server provides should be accurate, maybe keep track from which device the song was added to the playlist and if that device is fetching metadata dont send it the playlists row that was added using that device because it would already be stored in its database
13. the playlist_songs time_added column is out of sync from the server, check the addToLikedSongsPlaylist function, its because of the above issue? or not.. i should probably return the full playlist_songs row from the /music/add_playlist_to_song route and use that to keep client in sync
14. currently there is no way to remove a song from the Liked Songs playlist, maybe thats a good thing idk lol
15. currently there is no way to add playlists or add songs to playlists or do anything related to playlists at all except for the Liked Songs playlist lol
16. i think when a songs audio gave an error while being downloaded the audio for the next songs in the queue wont be downloaded as the queueCallBack wont be called
18. the functions in dataanalysis module need to be rewritten, they dont calculate things right
19. when you switch to another album after requesting a song to be downloaded it wont show that the song was downloaded if you come back to that album and it finishes downloading a song from that album after u came back to it from another album, i have to give a callback to the downloader that would reset the state of the widget when its done downloading

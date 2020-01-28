# bugs that im aware of
1. sometimes the PlayPause button is synced correctly, i have to add onPlay, onPause, onResume
   listeners to it regardless of them existing in it's parent widget
2. need a better way to play songs that dont exist locally but remotely than just add them to the
   queue once they're downloaded..
3. the Data section is yet to be built, tho data collection code is (i think) finished
3. sometimes when downloading multiple songs at once, the image for the current song doesnt get added to the musicwidget player coorectly
4. i should add an option to prioritize downloads and another to download all songs at once, but that would require me to save downloading progress and save it when the app is exited
5. i need to check for corrupted local files, if an audio file is corrupted, the applications goes crazy and the music monitor starts spamming the database with alot of playbacks

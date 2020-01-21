# player

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# bugs that im aware of
1. sometimes the PlayPause button is synced correctly, i have to add onPlay, onPause, onResume
   listeners to it regardless of them existing in it's parent widget
2. need a better way to play songs that dont exist locally but remotely than just add them to the
   queue once they're downloaded..
3. the Data section is yet to be built, tho data collection code is (i think) finished

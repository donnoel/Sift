SIFT — QUICK START

1) Requirements
- Xcode 15 or newer (iOS 17+ SDK recommended).
- A TMDB API key (v3).

2) Run the app
- Open the project in Xcode.
- Build & Run on iOS simulator or device.

3) Set your TMDB API Key
- In the app, go to Settings.
- Paste your key and tap “Apply.” The key is stored in UserDefaults and read by TMDBClient.

4) Importing Movies
- On Settings, paste one title per line and tap “Import.”
- The app will fetch matches from TMDB. Progress and up to three recent errors are shown.
- The library is persisted at: Documents/library.json

5) Caching
- Posters are cached in memory (NSCache) and on disk under the Caches directory (ImageCache/).

6) Troubleshooting
- If images flicker or scrolling feels janky in Library, ensure MovieCard reserves a fixed poster aspect ratio and that cached images are used when available.
- If you accidentally committed build artifacts, use the provided .gitignore (Sift.gitignore) and remove tracked files: 
  git rm -r --cached .
  git add .
  git commit -m "chore: clean build artifacts and apply .gitignore"

7) Notes
- The current Info.plist enables remote notifications; Entitlements include CloudKit. These are safe to keep or can be removed later if not used.

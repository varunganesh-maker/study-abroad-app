# Study Abroad app

A personal iPhone app for Varun's study-abroad semester in Australia. It turns the semester into a
map of memories: places get logged, the camera roll sorts itself onto the map by city, and later
the app recommends things to do based on what Varun actually rates highly.

Full product plan: https://claude.ai/artifact/KFxnJczCN5xMxzU99j5KvD
API research: https://claude.ai/artifact/Lz6NibGCGPySGwpCVXrjPC

## Who you're working with

Varun has very little coding experience (some Python) and has Claude write all the code.
- Explain changes in plain language. No jargon without a one-line explanation.
- Work in small slices that Varun can run on their iPhone and check.
- When Varun needs to do something in Xcode, give click-by-click steps.

## Stack

- Native iOS, **SwiftUI + MapKit**, iPhone only, iOS 17+. Swift 5 language mode.
- Apple frameworks: **Photos (PhotoKit)** for the camera roll, **Core Location** for geocoding and
  (phase 2) visit detection with `CLVisit`.
- Planned: SwiftData + iCloud (CloudKit) for storage; one small serverless function (e.g. Cloudflare
  Workers) to hold Google Places + Claude API keys for recommendations.
- No paid Apple Developer account yet: builds use free signing and expire from the phone after 7 days.
  Re-run from Xcode to reinstall.

## Project layout

The Xcode project uses a *synchronized folder* (Xcode 16+): any `.swift` file added under
`StudyAbroad/` is compiled automatically. **Don't hand-edit `project.pbxproj` to add files.**

```
StudyAbroad/
  StudyAbroadApp.swift      app entry point
  ContentView.swift         permission gate + tab bar (Memories, Cities)
  Models/                   PhotoMemory (pointer to a camera roll item), CityCluster
  Services/
    PhotoLibraryScanner     reads geotagged photos/videos from Photos
    CityGrouper             groups memories into cities (see below)
    KnownCities             Australian city circles (geocoder returns suburbs there)
    MemoryStore             app state, scans on launch and each time the app opens
    PhotoLoader             loads thumbnails / full images / videos on demand
    LocationProvider        current location (While Using only) for the map sparkle + "You're in…" card
  Views/
    Theme                   colours from the Figma mockups
    MemoriesMapView         night-style map home screen
    CityStoryView           a city's page: latest-day card + "Your days" row
    AllMemoriesView         every memory in a city, by day or by type
    MemoryViewer            full-screen story viewer with custom video controls
    CityListView, PermissionView, AssetThumbnail
```

Settings that would normally live in Info.plist are build settings (`INFOPLIST_KEY_*`) in
`project.pbxproj`, e.g. the photo permission message.

## Design

Screens follow Varun's Figma mockups: https://www.figma.com/design/XiGd2aOYGruzViIPRr56sN
(10 screens; Memories map, Sydney stories, All memories and Memory viewer are built). Use the Figma
connector to read a frame before changing a screen. Accent colour is indigo (AccentColor asset).

## How city grouping works (phase 1)

1. Photos inside a `KnownCity` circle go to that city with no network call. Needed because Apple's
   geocoder names Australian **suburbs** ("Bondi Beach"), not "Sydney".
2. Everything else is bucketed into ~0.1° (≈11 km) grid cells; one `CLGeocoder` reverse-geocode per
   cell gives the town name. Results are cached in `UserDefaults`. Apple throttles geocoding to about
   one request per second, so first launch on a big library names places progressively.
3. Cells with the same name + country merge.

`CLGeocoder` is deprecated in iOS 26 (still works; expect a warning). Moving to
`MKReverseGeocodingRequest` is a reasonable later cleanup.

## Building and checking your work

- CI: `.github/workflows/build.yml` compiles for the simulator on every PR. Check it passes.
- Locally on a Mac: `xcodebuild build -project StudyAbroad.xcodeproj -target StudyAbroad -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO`
- The simulator has few geotagged photos. Drag photos onto the simulator window to add some, or test
  on the real phone.

## Roadmap

1. **Memories map** (in progress). Done: scan camera roll, group by city, map pins with photo
   thumbnails, city grid, full-screen swipe viewer with video. Next: places within a city (~100 m
   clusters), city "story" view (Instagram-stories style, videos autoplay muted), saving to SwiftData.
2. **Visits.** Background `CLVisit` detection, visit inbox ("You were at Bondi for 2 h, rate it?"),
   rating 1 to 10 + recap, place page. (Reports of iOS 26 `didVisit` regressions: keep a backup such
   as significant-location-change.)
3. **Discover.** Google Places (New) for candidates, Claude re-ranks against Varun's ratings and writes
   a one-line "why". Tripadvisor for attractions. Skip Yelp (thin in Australia).
4. **Beli + extras.** Beli has no API: screenshot sync (Vision OCR of Beli screenshots in the camera
   roll) + "Rate in Beli" quick-switch buttons. Private-API sync only if Varun explicitly says go.
   Camcorder import: clips have no GPS, so place them by matching timestamps to phone location history.

## Data model (planned)

City, Place, Visit, Rating, Memory (photo library ID pointer, never a copy), BeliRating (kept separate
so imports never overwrite Varun's own ratings).

## Rules

- Photos never leave the phone. The app stores pointers (`localIdentifier`), not copies.
- Ask Varun before starting a new phase or anything that costs money.

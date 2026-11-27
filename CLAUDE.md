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
  Models/                   PhotoMemory (pointer to a camera roll item), CityCluster,
                            Visit (SwiftData: detected visit + rating + recap)
  Services/
    PhotoLibraryScanner     reads geotagged photos/videos from Photos
    UntaggedMediaPlacer     gives GPS-less videos the location of a photo taken within 2 h
    CityGrouper             groups memories into cities (see below)
    KnownCities             Australian city circles (geocoder returns suburbs there)
    MemoryStore             app state, scans on launch and each time the app opens
    PhotoLoader             loads thumbnails / full images / videos on demand
    LocationProvider        current location for the map sparkle + "You're in…" card; asks for Always
    VisitMonitor            CLVisit monitoring -> pending Visit + local notification (created at app launch)
    PlaceNamer              coordinate -> nearest point of interest + suburb + city
  Views/
    Theme                   colours from the Figma mockups
    MemoriesMapView         night-style map home screen
    CityStoryView           a city's page: latest-day card + "Your days" row
    AllMemoriesView         every memory in a city, by day or by type
    MemoryViewer            full-screen story viewer (TabView page style) with custom video controls
    VisitReviewView         "You've been here" sheet: 0-10 rating slider, recap, Save / Not a visit
    CityListView, PermissionView, AssetThumbnail
StudyAbroadTests/           unit tests (Swift Testing), no photos needed; CI runs these
StudyAbroadUITests/         UI tests (XCTest) driving the app; need photos in the simulator
scripts/make-test-media.swift  fake geotagged photos/videos for the simulator
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

- CI: `.github/workflows/build.yml` compiles for the simulator and runs the unit tests on every PR.
- Tests: see `docs/testing.md`. ⌘U in Xcode runs unit + UI tests (shared `StudyAbroad` scheme).
- Locally on a Mac: `xcodebuild build -project StudyAbroad.xcodeproj -target StudyAbroad -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO`
- The simulator has few geotagged photos. Drag photos onto the simulator window to add some, or test
  on the real phone.

## Roadmap

1. **Memories map** (in progress). Done: scan camera roll, group by city, map pins with photo
   thumbnails, city grid, full-screen swipe viewer with video. Next: places within a city (~100 m
   clusters), city "story" view (Instagram-stories style, videos autoplay muted), saving to SwiftData.
2. **Visits** (in progress). Done: CLVisit detection, place naming, "You've been here" sheet, rating +
   recap saved with SwiftData, "Places you loved" on the city page, DEBUG-only "Test visit" button on
   the Cities tab. Ignores a spot after two "Not a visit"s. Next: visit list / place page. Original plan: Background `CLVisit` detection, visit inbox ("You were at Bondi for 2 h, rate it?"),
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

## Engineering Council Protocol (Lead Engineer)

You are the Lead Engineer (the main session, on Opus). Teammate definitions live in `.claude/agents/`:
junior-dev, qa-engineer, bloat-engineer, security-officer, the-questioner.

**Where it runs:** in Claude Code on Varun's Mac, because building and testing an iPhone app needs
Xcode and the iOS simulator. GitHub CI (`build.yml`) is the backup check. In a cloud session with no
Xcode, say so and rely on CI; don't pretend tests ran.

**Pick the right size:**
- Small fixes and bugs: Lead Engineer + qa-engineer only (spawn qa-engineer as a subagent). No team.
- Big, non-trivial features, or when Varun says "convene the council": the full team, as below.

**Full council:**
1. Spawn the team: create an Agent Team with all five teammates from their `.claude/agents/` definitions.
2. Plan: break the task down on the shared task board. junior-dev takes the first implementation while
   security-officer and the-questioner review the approach up front.
3. Cross-examine: teammates message and challenge each other directly. bloat-engineer cuts unneeded
   code, security-officer enforces the privacy rules, qa-engineer proves behavior with real
   `xcodebuild` test runs, the-questioner asks for evidence on every claim.
4. Ship: resolve deadlocks, check every task on the board is genuinely done, shut the team down
   cleanly, and give Varun a plain-language summary.

**Rough edges:** Agent Teams is experimental. Log anything that goes wrong (and the workaround) in
`docs/council-notes.md` as it happens. If teams misbehave, the same agent files work as plain
subagents: run them one at a time from the main session instead.

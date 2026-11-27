# Study Abroad app

A personal iPhone app for Varun's study-abroad semester in Australia. It turns the semester into a
map of memories: places get logged, the camera roll sorts itself onto the map by city, and later
the app recommends things to do based on what Varun actually rates highly.

Current plan (v2, Nov 27 2026): https://claude.ai/artifact/5EocFSLuSThYZfDLwF8UHL
Original product plan (v1): https://claude.ai/artifact/KFxnJczCN5xMxzU99j5KvD
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
    MemoryViewer            full-screen story viewer with custom video controls
    VisitReviewView         "You've been here" sheet: 0-10 rating slider, recap, Save / Not a visit
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

## Product goals (v2 plan)

- Varun leaves for Australia **Jan 3, 2027**. Build for a possible public App Store launch later
  (no hard-coded personal data, real onboarding), but it's Varun's personal travel app for now.
- The #1 thing to nail: **scrapbooking memories easily**, starting with captions on photos AND
  videos (any length) and fast capture.
- **Priority order:** 1 Captions + capture, 2 Visits & ratings, 3 Recommendations, 4 Trips,
  5 Scrapbook, 6 Beli, 7 Camcorder import, 8 Sharing links (last; needs a server).
- Capture: camera roll picker first, then in-app camera, voice notes, text notes, home screen widget,
  and a setting "auto-add new photos: for a trip's dates / from now on / off". Apps can't hook into
  Apple's Camera app; auto-add is the substitute.
- Budget is **~$0/month**. Free tiers only (CloudKit in the user's own iCloud, Apple geocoding,
  Google Places free allowance behind a Cloudflare Worker; CloudKit later, with a paid account). Anything paid (e.g. Claude Haiku for
  "why you'll like it", ~$1-3/mo) needs Varun's yes first.
- Music: **Spotify**, not Apple Music. Spotify's 2026 dev-mode rules cap API apps at 5 Premium users,
  so use Spotify **embed players** from a pasted link, not the Spotify API/SDK.
- **No paid Apple Developer account for now** (Varun, Nov 27): build everything on free signing.
  No CloudKit (use a backup file exported to Files/iCloud Drive instead), no widget (needs App Groups),
  no TestFlight. Don't add capabilities free signing can't provision. Builds expire after 7 days, so
  in Australia Varun needs the Mac to reinstall, or buys the account before leaving.
- Phone: plan for iPhone 15 (no Camera Control, no Apple Intelligence on the base model).
- Name and branding are deferred; keep the Figma style.

## Roadmap to Jan 3 (must-ship line after week 5)

Each week ends with a build Varun installs and uses.
1. **Nov 30-Dec 6:** fix "View all" (swipe through every memory) and videos not showing; save
   memories in SwiftData; captions on photos and videos.
2. **Dec 7-13:** camera roll picker, auto-add setting, in-app camera, voice + text notes, backup file export/restore.
3. **Dec 14-20:** visit inbox, place page, manual "I was here", backup visit detection
   (significant-location-change; iOS 26 `didVisit` regressions reported).
4. **Dec 21-27:** recommendations (food, sights, nightlife, day trips, hidden gems; ranked by Varun's
   ratings; want-to-go list), trips with legs and auto-sorting.
5. **Dec 28-Jan 2:** trip page + highlights, bug sweep, full council version check, fresh Xcode install before the flight.

**Must-ship line.** Stretch: scrapbook v1 (auto-draft from dates, 3-4 templates, reorder).
If a week slips, cut in this order: itinerary drag-and-drop, hidden gems. Never cut captions,
capture, visits or basic recommendations.
From Sydney (Jan-Feb 2027): full scrapbook (free layout, stickers, ticket stubs, Spotify per page or
section), AI trip recap, Beli screenshot sync, camcorder import, sharing links. Widget + CloudKit sync
once Varun buys the dev account.

Already built: memories map, city grouping, Figma-styled city/all-memories/viewer screens, CLVisit
detection with "You've been here" sheet (0-10 rating + recap in SwiftData), DEBUG "Test visit" button.

## Data model (planned)

City, Place, Visit, Rating, Memory (photo library ID pointer, never a copy), BeliRating (kept separate
so imports never overwrite Varun's own ratings).

## Rules

- Photos never leave the phone. The app stores pointers (`localIdentifier`), not copies.
- Ask Varun before starting a new phase or anything that costs money.
- Beli has no API: screenshot sync (Vision OCR) + "Rate in Beli" buttons. Private-API sync only if Varun explicitly says go.
  BeliRating stays separate so imports never overwrite Varun's own ratings.
- Camcorder clips have no GPS: place them by matching timestamps to phone location history.

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

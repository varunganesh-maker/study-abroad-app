# Plan: "Readable, findable, searchable" PR (approved by Varun 2026-11-27)

Scope (Varun approved items 1-6):

1. Readable everywhere. Root cause: MemoriesMapView forces `.environment(\.colorScheme, .light)` on the
   Capture and Settings sheets while the map's `.environment(\.colorScheme, .dark)` leaks in and the sheet's
   UIKit background follows the phone's dark mode -> black text on a dark sheet. Fix: sheets use
   `.preferredColorScheme(.light)` (applies to the whole presentation: background, nav bar, text).
   Sweep every screen. Unit test forbids `.environment(\.colorScheme, .light)` in source and checks Theme
   text/background contrast ratios >= 4.5. Rule added to CLAUDE.md.
2. Moments you can always find. MemoryStore remembers the last thing you saved (`justSaved` id). When the
   rebuilt cities contain it, the map flies to that city and shows "Saved to <city> · View" (View opens it
   in the viewer). A "Recently added" row on the map footer shows hand-added memories (MemoryEntry.addedAt,
   source != autoAdd) from the last 7 days. Photo/video capture with no known place asks you to pick one
   instead of saving off-map.
3. Search a city: magnifier on the map header opens "Find a city" (search by city, country or caption
   words); Cities tab gets `.searchable`. Pure `CitySearch` helper with tests.
4. Map switch City / Country / World. Opens on the current city (or the latest memory's city if location is
   off), until you move the map yourself. Country label is dynamic (the focus city's country, or the country
   nearest the map centre at country zoom). Country region = known extent table (AU, NZ, US...) or the
   bounding box of your cities there. Pure `MapScope` logic with tests.
5. Place page (junior-dev): tap a rated place -> name, rating + words, every visit there with recap, the
   memories taken within ~150 m, small map, "Open in Maps", "Rate again". From Ratings tab and "Places you
   loved" on the city page. Pure `PlaceDetails` helper with tests.
6. Backup visit detection: when location is "Always", also start significant-location-change monitoring.
   `BackupVisitDetector` (pure, state in UserDefaults) turns "stayed near point A for 20 min - 8 h, then moved
   > 400 m" into a candidate visit. VisitMonitor dedupes by time overlap; a real CLVisit replaces an
   overlapping pending backup visit with its more precise spot. `Visit.sourceRaw` (default "visit") added.
   No new capabilities/background modes; no data leaves the phone.

Constraints: free signing (no new capabilities), $0, photos never leave the phone, don't touch signing.
No Xcode in the cloud: CI build + unit tests are the check.

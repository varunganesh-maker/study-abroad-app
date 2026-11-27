# Testing

Two kinds of tests, both run with **⌘U** in Xcode (Product → Test):

| Folder | What it checks | Needs photos? |
|---|---|---|
| `StudyAbroadTests/` | **Unit tests**: small pieces of logic, e.g. placing videos that have no GPS. Run in under a second. | No |
| `StudyAbroadUITests/` | **UI tests**: launch the app in the simulator, tap through View all, swipe the viewer, play a video. | Yes |

New `.swift` files in either folder are picked up automatically (synchronized folders, like the app).

## Running from Terminal

```sh
# Unit tests only (what CI runs on every PR)
xcodebuild test -project StudyAbroad.xcodeproj -scheme StudyAbroad \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:StudyAbroadTests

# Everything, including UI tests (takes ~7 minutes)
xcodebuild test -project StudyAbroad.xcodeproj -scheme StudyAbroad \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Giving the simulator some photos

UI tests skip themselves if the simulator's camera roll has no geotagged photos. To fill it with
fake ones (coloured cards in Sydney, 8 videos, plus one video without GPS):

```sh
swift scripts/make-test-media.swift /tmp/test-media
xcrun simctl addmedia booted /tmp/test-media/*
```

Then open the app once in that simulator and allow photo access.

## Notes

- The simulator sometimes drops a fake swipe, so the UI tests retry a swipe once before failing.
- UI tests on the real iPhone work too (plug it in, pick it as the destination, ⌘U). They only tap
  through the app; nothing leaves the phone.

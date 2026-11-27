# Study Abroad

A personal iPhone app that turns a study-abroad semester into a map of memories.
Phase 1: scans your camera roll and puts geotagged photos and videos on a map, grouped by city.

## Run it on your iPhone

You need a Mac with **Xcode 16 or newer** (free from the Mac App Store) and a USB cable for your iPhone.

1. **Get the code.** On this GitHub page click the green **Code** button → **Download ZIP**, then
   double-click the ZIP in Downloads to unzip it. (Or in Xcode: **Clone Git Repository…** on the
   welcome screen and paste the repo URL.)
2. **Open the project.** Double-click `StudyAbroad.xcodeproj` in the unzipped folder. Xcode opens.
3. **Sign in to Xcode with your Apple ID.** Menu bar: **Xcode → Settings… → Accounts** → **+** →
   **Apple ID**, and sign in. This is free; no paid developer account needed.
4. **Save your team (once).** Build once so Xcode makes your free signing certificate: in the left
   sidebar click the blue **StudyAbroad** icon, then **Targets → StudyAbroad → Signing & Capabilities**,
   and set **Team** to *your name (Personal Team)*. Then open **Terminal**, `cd` into the project folder
   and run `scripts/setup-signing.sh`. It saves your team in `Config/Local.xcconfig`, a file git ignores,
   so pulling new code never resets it. Finally discard the change Xcode made to the project file:
   `git checkout -- StudyAbroad.xcodeproj/project.pbxproj`. Close and reopen the project.
   - If it complains the bundle identifier is taken, change **Bundle Identifier** to something unique,
     like `com.yourname.studyabroad2`.
5. **Plug in your iPhone** and unlock it. Tap **Trust** if it asks.
6. **Turn on Developer Mode on the iPhone:** **Settings → Privacy & Security → Developer Mode** → on,
   then restart the phone when it asks. (The option only appears after step 5.)
7. **Choose your phone** in the device menu at the top of the Xcode window (next to "StudyAbroad"),
   then press the **▶ Run** button (or ⌘R). The first build takes a minute.
8. **Trust yourself on the iPhone** (first time only): if the app won't open, go to
   **Settings → General → VPN & Device Management**, tap your Apple ID, and tap **Trust**.
9. Open the app, tap **Allow Photo Access** and choose **Allow Full Access**.

The map fills in as it names your places (Apple limits this to about one place per second, so a big
camera roll takes a few minutes the first time; it's remembered after that).

**Heads-up:** with a free Apple ID the app stops opening after 7 days. Plug in and press ▶ Run again
to reinstall; your data isn't lost.

## Working on it

This app is built with Claude Code. `CLAUDE.md` holds the plan and conventions for every session.

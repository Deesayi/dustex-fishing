# DUSTEX iPhone + iPad apps

Two apps from one small Xcode project:

- **Creator Studio**: DUSTEX Creator Studio (opens https://deesayi.github.io/dustex-fishing/tab/)
- **Forecaster**: DUSTEX Fishing Forecaster (opens https://deesayi.github.io/dustex-fishing/)

Each app is a full-screen, dark, native shell around the web app, so it always has the newest version. After the first launch with internet, the site's offline copy lets it open anywhere. Creator Studio asks for the microphone the first time you press Listen (or arm the looper / AUX).

## Built automatically

Every push that changes `ios/` runs **Actions > iOS apps** on a GitHub Mac. It builds both apps for the iPhone/iPad simulator, which proves the project compiles, and attaches `DustexApps-xcode-project.zip` (a ready Xcode project) and `DustexApps-simulator.zip`.

## Putting them on your own iPhone / iPad, or in the App Store

You need a Mac with Xcode and an Apple ID (free for your own devices; the $99/year Apple Developer Program for the App Store).

1. On the Mac: `brew install xcodegen`, then in this folder run `xcodegen generate` (or unzip `DustexApps-xcode-project.zip` from the Actions run).
2. Open `DustexApps.xcodeproj`, pick the **TabCreatorStudio** or **FishingForecaster** target, and under *Signing & Capabilities* choose your team.
3. Plug in the iPhone or iPad and press **Run**. For the App Store: *Product > Archive*, then *Distribute App*.

The bundle IDs are `com.dustex.tabstudio` and `com.dustex.fishingforecaster`; change them in `project.yml` if Apple says they are taken.
Note for App Store review: Apple asks that apps do more than show a website (guideline 4.2). Both apps work offline, use the microphone, notifications and touch controls, which helps, but review is up to Apple.

## Without a Mac

Both web apps install straight from Safari: open the link, tap **Share > Add to Home Screen**. They run full screen and offline, the same as these apps.

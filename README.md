# Chaptr iOS Prototype

Native SwiftUI prototype for Chaptr's mobile engineering exercise: a full-screen vertical For You feed that streams one short-form video at a time from the provided local catalog.

Walkthrough:

- App demo: [ChaptriOSAppDemo.mp4](https://drive.google.com/file/d/1E_TLC4qOriaQdwq8-RF0IpOClD3C_Xd-/view?usp=drive_link)
- Instrumentation addendum: [ChaptrInstrumentationDemo.mov](https://drive.google.com/file/d/14k-LrziczlCUGaK5xzlmpo132ikPFjEa/view?usp=drive_link)
- Codebase quick review: [ChaptrCodeBaseQuickReview.mov](https://drive.google.com/file/d/1-VCmaStc43pHRbDE2q0MueHPoZkmAmCQ/view?usp=sharing)

## Build And Run

Requirements:

- Xcode 26.5 or newer
- iOS Simulator runtime installed
- Network access for Pexels-hosted MP4 and poster URLs

Steps:

```sh
open Chaptr.xcodeproj
```

Then select the `Chaptr` scheme, choose an iPhone simulator, and run.

Command-line build:

```sh
xcodebuild -project Chaptr.xcodeproj -scheme Chaptr -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Command-line tests:

```sh
xcodebuild test -project Chaptr.xcodeproj -scheme Chaptr -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO
```

## What I Built

- A portrait-first SwiftUI For You feed with one full-screen video per page.
- Local JSON catalog loading from `Chaptr/Resources/for-you.json`.
- Native AVFoundation playback through a custom `AVPlayerLayer` bridge.
- Autoplay for the active item and immediate pause for off-screen items.
- Bounded preloading: previous 1, active, and next 2 players are retained.
- Per-item loading, stalled, failed, and retry states.
- Default-on audio with mute control, looping, progress, poster fallback, and foreground/background pause-resume behavior.
- Memory-warning handling that trims retained players back to the active item.
- A short-form overlay with title, ML-assisted generated description, duration, progress, and compact controls.

## Architecture

The app uses feature-first MVVM with a dedicated playback coordinator.

- `Data`: `CatalogRepository` loads the bundled read-only catalog.
- `Models`: typed catalog, video, load, and playback states.
- `Features/ForYou/ViewModels`: `ForYouViewModel` coordinates feed state and user intent.
- `Features/ForYou/Playback`: `PlaybackCoordinator` owns `AVPlayer` creation, preloading, pausing, retry, looping, progress, and cleanup.
- `Features/ForYou/Views` and `Components`: SwiftUI rendering only.
- `Shared`: small reusable formatting, on-device visual description, metadata fallback, and poster helpers.

Files are intentionally small and split by responsibility. There are no source comments or TODO placeholders.

## Optimization Choice

I optimized for perceived speed with bounded memory. Short-form feeds feel broken when swipes land on black frames, but retaining too many players can quickly become unstable. The coordinator keeps the current item ready, preloads the next two, keeps one previous item warm, and releases everything else.

This gives rapid swipes a better first-frame chance while preventing unbounded player growth after long sessions.

## Edge Cases Covered

- Missing, invalid, or empty catalog states.
- Invalid video URLs isolated to a single feed item.
- Slow first frame with poster/loading UI.
- Stalled playback and retry.
- Rapid index changes without stale off-screen playback.
- End-of-video looping.
- Loop replay respects the active item and foreground state.
- Background and foreground transitions.
- iOS memory warnings trim the warm player cache.
- Bounded player cache during long scroll sessions.
- Small-screen text readability through line limits, scaling, and gradients.

## What I Skipped

- Backend, auth, analytics, social actions, comments, likes, or sharing.
- Persistent watch history.
- Offline download/cache storage.
- Custom video transcoding or CDN selection.

Those would be product and infrastructure decisions outside the provided exercise scope.

## Tradeoffs

- Descriptions are generated locally with an on-device Vision classification pass over the poster image, then composed with title, thumbnail, and duration metadata. Catalog-provided descriptions win first, and the older metadata-only builder remains as a deterministic fallback when image loading, classification, or confidence is not good enough.
- The player cache is intentionally small. A larger cache might reduce stalls on very fast networks, but it would increase memory risk.
- I used native AVFoundation instead of a third-party player to keep behavior explicit and reviewable.
- The UI is inspired by the reference mockups, but avoids copying unrelated platform chrome.

## With Another Week

- Add persistent watch progress and lightweight local ranking signals.
- Add offline poster caching and smarter retry/backoff.
- Add more precise first-frame timing instrumentation and automated network-condition testing.
- Add UI automation for retry recovery under simulated media failures.
- Add adaptive preload sizing based on device memory and network quality.
- Add a first-class editorial review tool for descriptions so ML-assisted copy can be approved or overridden before a large catalog ships.

## Biggest Scaling Risk

At thousands of videos and real users, the biggest risk is feed delivery quality rather than local rendering. The app would need server-side ranking, CDN-aware URL selection, video variant selection, poster caching, and telemetry for stalls, first frame time, failures, memory pressure, and swipe behavior. Without that feedback loop, the product can look fine in a small catalog but degrade unpredictably in production.

## Verification

Included tests cover catalog decoding, ML-assisted description composition, cache/fallback/failure paths, async view-model enrichment, empty/failure view-model states, preload-window behavior at start, middle, end, rapid index changes, background/foreground behavior, continuous scrolling, and 50+ scroll stress.

Latest local verification:

- `xcodebuild -checkFirstLaunchStatus`: exit 0
- `xcrun simctl list runtimes available`: iOS 26.5 available
- `xcodebuild test -project Chaptr.xcodeproj -scheme Chaptr -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:ChaptrTests`: `TEST SUCCEEDED`, 49 tests, 0 failures
- `xcodebuild test -project Chaptr.xcodeproj -scheme Chaptr -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:ChaptrUITests/ChaptrInteractionTests`: `TEST SUCCEEDED`, 5 tests, 0 failures

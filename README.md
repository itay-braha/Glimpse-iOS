# Glimpse (iOS app)

The SwiftUI client of **Glimpse**, a video-first dating app with a 20-connection cap.

This repository holds the iOS app only. It runs fully in **demo mode** (seeded profiles,
simulated replies, a simulated Vibe Check partner). The backend that powers the real
service is not part of this repository.

**Not open source.** See [LICENSE](LICENSE): viewing and private, non-commercial study are
allowed; commercial use, redistribution and use of the Glimpse name or brand are not.
Copyright (c) 2026 Itay Braha. All rights reserved.

## Build

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
cd ios && xcodegen && open Glimpse.xcodeproj
```

Run with the launch arguments `-demo -screen feed` (or `welcome`, `match`, `connections`,
`chat`, `profile`, `likes`, `paywall`, `settings`).

## CI

Every push builds the app, runs unit and UI tests on an iPhone simulator, records the
simulator screen, and uploads screenshots of each step plus the screen recording as a
workflow artifact.

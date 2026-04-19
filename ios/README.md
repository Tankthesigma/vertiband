# VertiBand · iOS App

SwiftUI 5 / iOS 17+ companion app. Matches the marketing site's design
language (paper cream + ink navy + terracotta accent, Fraunces / Inter /
JetBrains Mono).

## First-run setup on your Mac (90 seconds)

```sh
# 1. One-time tools (if you don't already have them)
brew install xcodegen

# 2. Generate the Xcode project from ios/project.yml
cd ios
xcodegen generate

# 3. Open in Xcode
open VertiBand.xcodeproj
```

In Xcode:

1. **Signing & Capabilities** → team = your Apple ID (free account works).
2. Plug iPhone into your Mac. Tap **Trust** on the phone.
3. Select the phone at the top device bar. **⌘R** to run.

First launch on the phone: iOS will ask you to trust the developer. Go to
**Settings → General → VPN & Device Management → `<Your Apple ID>` → Trust**.
You only do that once.

## Optional services

### Gemini (AI coaching + session note)
The app calls the Gemini API directly over HTTPS. In the app's **Settings**
tab, paste your Gemini API key (free key from `aistudio.google.com/app/apikey`
works). The key is stored in the iOS keychain — it never leaves your device.

### Pi bridge (use the physical VertiBand instead of the phone's gyro)
If you have the Raspberry Pi running on the same Wi-Fi, open **Settings** and
set the Pi URL (default `http://192.168.254.53`). Sessions will then drive the
Pi's amplifier for audio cues instead of the phone speaker. Leave blank to
use the phone only.

## Architecture

- **`@Observable`** macro for all state (2026 SwiftUI idiom).
- **`NavigationStack`** + typed destinations for routing.
- **MVVM-ish** — views are thin, logic lives in services / the session engine.
- **Services injected via `.environment`** at `VertiBandApp` root.
- **No third-party dependencies** — just Apple frameworks + URLSession for
  Gemini calls.

## File layout

```
ios/
├── project.yml                 ← XcodeGen spec
├── VertiBand/
│   ├── VertiBandApp.swift      ← @main, env, theme registration
│   ├── RootView.swift
│   ├── Info.plist
│   ├── Theme/                  ← colors, typography, reusable components
│   ├── Models/                 ← Session, Step, Epley config
│   ├── Services/               ← Motion, Audio, Gemini, Pi bridge, Store
│   ├── Session/                ← Epley state machine
│   ├── Features/               ← one folder per screen
│   └── Assets.xcassets/
```

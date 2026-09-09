# ConvertIt

macOS menu bar app for instant unit/currency conversions and batch media work — always one hotkey away.

**Website:** [convertitapp.com](https://convertitapp.com)  
**Part of:** [Spark Suite](https://sparksuiteapps.com)

## Features

- **Quick mode** — type conversions in plain language (`72f to c`, `10km to mi`)
- **Guided mode** — pick a category and units from menus
- **14 conversion categories** — temperature, distance, weight, volume, data size, speed, area, pressure, energy, fuel economy, time zones, currency, percentage, tip
- **Live currency rates** via [Frankfurter](https://frankfurter.dev) (ECB reference rates), cached locally for 24 hours
- **Media Convert** — batch convert images, video, and audio (AVFoundation + bundled LGPL FFmpeg)
- **Spreadsheets** — CSV, TSV, and Excel (XLSX)
- **Media Rename** — batch rename with pattern tokens (`{name}`, `{n}`, `{nn}`, `{ext}`)
- **Global hotkey**, Launch at Login, recents/pins, and macOS Services

Privacy-first: conversions run on-device. No accounts, analytics SDKs, or file uploads.

## Requirements

- macOS 14 or later
- Xcode 16+ (to build from source)
- Apple Silicon or Intel

## Open & run

```bash
open "Convert It.xcodeproj"
```

Select the **Convert It** scheme → My Mac → Run.

The app is a menu bar utility (`LSUIElement`). After launch, use the default hotkey or open it from the status item. Hotkey is configurable in Settings.

## Project layout

```
Convert It/                 SwiftUI app sources
├── Engine/                 Conversion, media, currency, FFmpeg helpers
├── Models/                 Categories, formats, settings, stores
├── Views/                  UI (Quick, Guided, Media, Settings, About)
├── Utilities/              Hotkey, status item, launch at login
└── Resources/              FFmpeg notice (binary is bundled at build time)

Scripts/                    FFmpeg build/bundle, DMG, verify, notarize
ThirdParty/FFmpeg/          LGPL compliance docs and build notes
BundledBinaries/            Local FFmpeg binary (gitignored)
```

## FFmpeg (LGPL)

ConvertIt bundles an **LGPL FFmpeg** command-line binary as a subprocess (not linked into the app). Builds omit `--enable-gpl` and `--enable-nonfree`. H.264 uses VideoToolbox, not `libx264`.

| Script | Purpose |
|--------|---------|
| `Scripts/build-ffmpeg-lgpl.sh` | Build LGPL FFmpeg + source tarball |
| `Scripts/bundle-ffmpeg.sh` | Copy into the app bundle (Run Script phase) |
| `Scripts/bundle-ffmpeg-dylibs.sh` | Rewrite dylib paths for App Sandbox |
| `Scripts/verify-app-bundle.sh` | Pre-release bundle checks |

Corresponding source for users: [convertitapp.com/legal/ffmpeg-source](https://convertitapp.com/legal/ffmpeg-source)

See `ThirdParty/FFmpeg/COMPLIANCE.md` for the full checklist.

## Release packaging

```bash
# After Product → Archive in Xcode:
./Scripts/create-release-dmg.sh
./Scripts/verify-app-bundle.sh "/path/to/Convert It.app"
```

Developer ID / notarization helpers live in `Scripts/notarize-release.sh` and `Scripts/ExportOptions.plist`.

Website downloads and changelog are maintained in the separate `convertit-site` project (deployed to Vercel).

## Version

Current marketing version: **1.1.1**  
Bundle ID: `sparkcustomer.com.Convert-It`

## License

ConvertIt’s original application code is proprietary © Sam Parker.  
Bundled FFmpeg and related libraries remain under their respective LGPL (and compatible) licenses — see About in-app and `Convert It/Resources/FFmpeg-NOTICE.txt`.

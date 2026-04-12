# StickNote

<p align="center">
  <a href="https://github.com/alex-fomin/StickNote/releases">
    <img src="https://github.com/alex-fomin/StickNote/blob/main/StickNote/Assets.xcassets/AppIcon.appiconset/icon_128x128.png?raw=true" width="120" alt="StickNote app icon">
  </a>
</p>

**StickNote** is a macOS menu bar utility for lightweight floating sticky notes. Notes support Markdown rendering, optional image notes from the clipboard, per-note layouts, and are stored with **SwiftData**.

Prebuilt downloads: **[Releases](https://github.com/alex-fomin/StickNote/releases)**.

**Product page:** [alex-fomin.github.io/StickNote](https://alex-fomin.github.io/StickNote/) — static site served from [`docs/`](docs/) on GitHub Pages (`index.html`, `site.css`, shared screenshot assets). It mirrors this README: hero pitch, feature grid, screenshot, requirements, and links to releases and the repo.

## Screenshot

<p align="center">
  <img src="docs/screenshots/notes-overview.png" width="720" alt="Several floating sticky notes showing simple text, Markdown, layouts, and an image pasted from the clipboard">
  <br>
  <em>Floating notes — simple text, Markdown, layouts, and an image from the clipboard.</em>
</p>

The same file is used on the [product page](https://alex-fomin.github.io/StickNote/) (`docs/screenshots/notes-overview.png`, **1932×1274** px).

## Features

- **Menu bar presence** — quick actions from the status item (single-click toggles note visibility; double-click opens a new note).
- **Floating notes** — always-on-top windows with draggable chrome and optional “maximize on hover” / “maximize after edit” behavior.
- **Markdown** — notes render Markdown in the note view (via [Down](https://github.com/johnxnguyen/Down) and related text stack).
- **Note list** — browse notes, including hidden ones, from a dedicated window.
- **Layouts** — choose default layout presets for new notes (editable in Settings).
- **Clipboard** — create a note from a pasted image when the pasteboard contains suitable image data.
- **Configurable shortcuts** — record global shortcuts in **Settings → General** for new note, paste-from-clipboard note, and show/hide all notes.
- **Optional launch at login** and other behaviors (delete confirmation, trash vs permanent delete, “show on all spaces,” menubar note count, etc.) in **Settings**.

## Requirements

- **macOS** 15.0 or later (project `MACOSX_DEPLOYMENT_TARGET`).
- **Xcode** with Swift 5 and SwiftPM (for building from source).

## Building from source

1. Clone the repository:

   ```bash
   git clone https://github.com/alex-fomin/StickNote.git
   cd StickNote
   ```

2. Open `StickNote.xcodeproj` in Xcode and build the **StickNote** scheme, **or** build from the terminal:

   ```bash
   xcodebuild -project StickNote.xcodeproj -scheme StickNote -configuration Debug \
     -destination 'platform=macOS' -derivedDataPath .build build
   ```

3. Run the built app:

   ```bash
   open .build/Build/Products/Debug/StickNote.app
   ```

Swift package dependencies are resolved automatically via Xcode (see `StickNote.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`).

## Third-party software

StickNote is built with **Swift**, **SwiftUI**, **SwiftData**, and **AppKit** (subject to Apple’s SDK and developer terms). It links these **direct** Swift Package Manager dependencies (transitive packages are not listed):

| Package | License |
|--------|---------|
| [Defaults](https://github.com/sindresorhus/Defaults) | MIT |
| [Down](https://github.com/johnxnguyen/Down) | MIT (see upstream for bundled components) |
| [FontPicker](https://github.com/tyagishi/FontPicker) | MIT |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | MIT |
| [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | MIT |
| [MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) | MIT |
| [Textual](https://github.com/gonzalezreal/textual) | MIT |

**Full attribution** (pinned versions, links to upstream license files, and an Apple tools note): [`StickNote/ThirdPartyNotices.md`](StickNote/ThirdPartyNotices.md). The same text is available in the app under **Settings → About → Third-party licenses…**.

## License

[MIT](LICENSE) — Copyright © 2025–2026 Alex Fomin.

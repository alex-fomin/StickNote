# Third-party software

StickNote incorporates open-source libraries distributed under the licenses below. Only **direct** SwiftPM dependencies of the StickNote app target are listed (not transitive packages they pull in). Resolved versions match `StickNote.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` at the time this file was last updated.

## Swift Package Manager dependencies

| Library | Version | License | Source |
|--------|---------|---------|--------|
| [Defaults](https://github.com/sindresorhus/Defaults) (includes DefaultsMacros) | 9.0.2 | MIT | [license](https://github.com/sindresorhus/Defaults/blob/main/license) |
| [Down](https://github.com/johnxnguyen/Down) | 0.11.0 | MIT (project bundles additional notices for cmark, CommonMark tests, and other upstream components) | [LICENSE](https://github.com/johnxnguyen/Down/blob/v0.11.0/LICENSE) |
| [FontPicker](https://github.com/tyagishi/FontPicker) | 1.2.0 | MIT | [LICENSE](https://github.com/tyagishi/FontPicker/blob/1.2.0/LICENSE) |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.2.3 | MIT | [license](https://github.com/sindresorhus/KeyboardShortcuts/blob/main/license) |
| [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | main @ `a04ec1c` | MIT | [license](https://github.com/sindresorhus/LaunchAtLogin-Modern/blob/main/license) |
| [MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) | 1.2.2 | MIT | [LICENSE](https://github.com/orchetect/MenuBarExtraAccess/blob/main/LICENSE) |
| [Textual](https://github.com/gonzalezreal/textual) | 0.3.1 | MIT | [LICENSE](https://github.com/gonzalezreal/textual/blob/main/LICENSE) |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 2.9.1 | MIT | [LICENSE](https://github.com/sparkle-project/Sparkle/blob/2.9.1/LICENSE) |

Transitive dependencies (for example libraries used by Textual or Defaults at build or run time) are omitted here; see each package’s repository for its full dependency tree and licenses.

## Apple platforms and development tools

StickNote is built with **Xcode** and links against Apple system frameworks and libraries (including **Swift**, **SwiftUI**, **SwiftData**, **AppKit**, and other SDK components). Use of those tools and SDKs is subject to the [Apple Developer](https://developer.apple.com/support/terms/) and Xcode license terms that apply to your Apple ID and distribution channel.

## Disclaimer

This list is provided for attribution. It is not legal advice. For the authoritative license text, refer to each package’s repository or the copy bundled with the dependency source.

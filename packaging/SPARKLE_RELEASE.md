# Sparkle updates (GitHub Releases)

StickNote uses [Sparkle](https://sparkle-project.org/) with `SUFeedURL` pointing at `packaging/appcast.xml` on the default branch (raw GitHub URL in [StickNote/Info.plist](../StickNote/Info.plist)).

## One-time: signing keys

1. Get Sparkle’s command-line tools (**do not** use Homebrew’s `sparkle` formula: it is deprecated and fails Gatekeeper). Prefer either:
   - **Official release:** Download the **Sparkle for macOS** archive from [Sparkle releases](https://github.com/sparkle-project/Sparkle/releases) (same major line as the app’s SPM dependency), unzip, and use `bin/generate_keys`, `bin/sign_update`, and `bin/generate_appcast` from that bundle.
   - **Same checkout as the app:** After Xcode resolves packages for this project, tools usually appear under  
     `.build/SourcePackages/artifacts/sparkle/Sparkle/bin/`  
     (or run `find .build/SourcePackages -path '*/Sparkle/bin/sign_update'` from the repo root).
2. Run **`generate_keys`**. It stores the **private** key in your login keychain and prints the **public** key for **`SUPublicEDKey`**.
3. Put the printed public key string in **`SUPublicEDKey`** in [StickNote/Info.plist](../StickNote/Info.plist). Never commit the private key; only the public key belongs in the repo.

If you did not create the key pair yourself (for example you are taking over releases from another machine), run **`generate_keys`** once and replace **`SUPublicEDKey`** so it matches the private key **`sign_update`** will use from your keychain. Ship an app build containing the new public key before publishing DMGs signed with that key.

If you replace the key pair, you must ship an app update containing the new `SUPublicEDKey` before publishing DMGs signed with the new private key.

## Each release

1. Bump version if needed ([scripts/publish-dmg.sh](../scripts/publish-dmg.sh) supports `minor` / `major`), build the Release DMG, and notarize as you usually do for distribution.
2. Create a **GitHub Release** and upload **`StickNote-<version>.dmg`** as a release asset. Note the stable download URL, e.g.  
   `https://github.com/alex-fomin/StickNote/releases/download/v1.3.0/StickNote-1.3.0.dmg`
3. Sign the DMG for Sparkle:

   ```bash
   sign_update path/to/StickNote-1.3.0.dmg
   ```

   Use `sign_update` from the **official Sparkle release bundle** or the **SPM artifacts path** above (same Sparkle version as the linked framework). It prints **`sparkle:edSignature`** and **`length`** for the appcast.

4. Add a new **`<item>`** to [appcast.xml](appcast.xml) with:
   - **`sparkle:version`** — must compare correctly with **`CFBundleVersion`** (build number) in the app; many setups keep marketing and build version aligned (see Sparkle [publishing](https://sparkle-project.org/documentation/publishing/) and versioning notes).
   - **`sparkle:shortVersionString`** — user-visible version string (`CFBundleShortVersionString`).
   - **`<enclosure>`** — `url` = GitHub asset URL, `length` from `sign_update`, `sparkle:edSignature` from `sign_update`, `type="application/octet-stream"` (or the appropriate type Sparkle recommends for your archive).

5. Commit and push **`appcast.xml`** so the raw URL in Info.plist serves the updated feed.

## Automation (recommended)

Use **[scripts/sparkle-release.sh](../scripts/sparkle-release.sh)** from the repo root:

- `./scripts/sparkle-release.sh build` — same as `publish-dmg.sh` (optional `minor` / `major`).
- `./scripts/sparkle-release.sh appcast v1.3.0` — runs **`generate_appcast`** against `dist/` and writes **`packaging/appcast.xml`**, with download URLs under `https://github.com/<owner>/<repo>/releases/download/v1.3.0/`. Set **`GITHUB_REPO`** if needed; set **`SPARKLE_ROOT`** to Sparkle’s `bin/` if Xcode artifacts are missing.

See the Cursor skill **sparkle-release** (`.cursor/skills/sparkle-release/SKILL.md`) for the full agent-oriented workflow.

## Optional manual notes

Sparkle’s **`generate_appcast`** can also be run by hand against a folder of archives; pass your private key via keychain (default) or **`--ed-key-file`** per **`generate_appcast --help`**. Keep **`dist/`** limited to the DMG(s) you intend for the feed so extra files are not ingested.

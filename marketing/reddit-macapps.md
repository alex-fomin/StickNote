# r/macapps post — StickNote

## Where to post

StickNote is not in the App Store and the repo has < 100 stars, so it goes to the current
**"[Megathread] The App Pile — <month>, 2026"** (pinned in r/macapps), not the main feed.

Main feed becomes possible later via one of:
- GitHub repo 1+ year old **and** 100+ stars (age is already OK, stars are not);
- Developer flair (500+ r/macapps karma + mod approval);
- "Transparency path": real-identity developer portfolio/LinkedIn **and** a site with Privacy Policy + Terms of Service.

## Rules checklist (as of 2026)

- 10+ r/macapps karma to post at all (earn it in comments first).
- One app promo per **developer** per 30 days.
- **PCP format** is mandatory, otherwise removed:
  - **Problem** — what the app solves;
  - **Comparison** — 1–2 named alternatives and why yours is better;
  - **Pricing** — amount + link.
- Open-source apps: prefix the title with **[OS]**.
- Flair priority: Vibe Coded > Lifetime > Subscription > Free (pick the highest that applies).
- Keep it short (mods suggest < 200 words); long posts with many lists look like AI.
- Screenshot encouraged.

## Megathread comment (PCP)

**[OS] StickNote — yet another floating notes app**

[screenshot / gif]

**Problem:** I wanted sticky notes that float above other windows and stay out of the way — minimal design, Markdown, and paste straight from the clipboard.

**Comparison:**
- *Apple Stickies* — rich text only, no Markdown, no global hotkeys. StickNote renders Markdown and turns the clipboard into a note with one hotkey; text copied from a web page or document comes in as clean Markdown (tables included), images become image notes.
- *Apple Notes* — great for archives, but notes don't float over your work. StickNote notes stay on top and collapse to a single line until you hover.

**Pricing:** Free, MIT-licensed. No account, no telemetry. macOS 15+, Apple Silicon.
- Site: https://alex-fomin.github.io/StickNote/
- Source: https://github.com/alex-fomin/StickNote

Feedback welcome!

## Main-feed version (for later, when eligible)

**Title:** [OS] Yet another floating notes app — StickNote (free, open source)

I'm the developer. I wanted sticky notes that stay out of the way, so I built my own.

**StickNote** is a small menu bar app for notes that float above your windows. It focuses on three things:

- **Minimal design**: no toolbars or sidebars, just the note. Notes collapse to a single line and expand on hover
- **Markdown**: headings, lists, code, links, and tables render right in the note
- **Clipboard paste**: one hotkey turns the clipboard into a note. Text copied from a web page or a document comes in as clean Markdown, and images become image notes

There's more under the hood (layouts, Inbox note, hide until…), but those three are the point.

Free, MIT-licensed, no account, no telemetry. macOS 15+, Apple Silicon.

- Site: https://alex-fomin.github.io/StickNote/
- Source: https://github.com/alex-fomin/StickNote

Feedback welcome!

> Before posting to the main feed, add the PCP pieces (Comparison + Pricing) — the version above alone would be removed.

## First-launch reply (keep handy for comments)

> The build isn't notarized yet, so macOS blocks the first launch. Try to open it once, then go to System Settings → Privacy & Security → Open Anyway, or run
> `xattr -d com.apple.quarantine /Applications/StickNote.app`. Only needed once.

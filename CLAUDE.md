# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
# Build
xcodebuild build -project app/Projects.xcodeproj -scheme Projects -destination 'platform=macOS'

# All tests
xcodebuild test -project app/Projects.xcodeproj -scheme Projects -destination 'platform=macOS'

# One suite, or one test
xcodebuild test -project app/Projects.xcodeproj -scheme Projects -destination 'platform=macOS' \
  -only-testing:ProjectsTests/AppStateTests
xcodebuild test -project app/Projects.xcodeproj -scheme Projects -destination 'platform=macOS' \
  -only-testing:ProjectsTests/AppStateTests/refreshLoadsSnapshotAndTitle
```

There is no linter. `app/src/` and `app/tests/` are `PBXFileSystemSynchronizedRootGroup`s, so a new file is picked up by
path — never hand-edit `project.pbxproj` to add one.

## What the app is

A `LSUIElement` menu bar app (no Dock icon, no main window) that names macOS Spaces and, per Space, reopens saved
iTerm2 window layouts and a Chrome window of URLs. The README covers the user-facing behaviour and the macOS
permissions involved; read it before changing behaviour.

## Architecture

`AppState` (`app/src/AppState.swift`) is the only stateful object. It is `@MainActor @Observable`, owns `ProjectStore`
and `ShortcutStore`, and every view reads it through `@Bindable`. Everything it talks to the system with is behind a
seam it takes in `init`: `SpaceProviding`, `OverlayShowing`, the Mission Control shortcut reader closure, and
`UserDefaults`. Tests substitute fakes for all four; keep new system access behind the same pattern rather than
calling into AppKit from `AppState` directly.

Three collaborating pieces of macOS trickery, each isolated in its own file:

- **Reading Spaces** — `SpaceProvider` `dlopen`s SkyLight and calls the private `CGSCopyManagedDisplaySpaces`. A
  missing symbol logs and yields an empty list rather than trapping. `SpaceList.parse` turns the raw dictionaries
  into a `SpaceSnapshot`; it reads the first display only and keeps only `type == 0` (desktop) entries, so Space
  numbers are positions in that filtered list, matching how macOS numbers them left to right.
- **Switching Space** — the app does not call any API. `MissionControlShortcuts` reads the user's
  "Switch to Desktop N" key combos out of `com.apple.symbolichotkeys`, and `SpaceSwitcher` posts that combo as a
  CGEvent. A Space with no assigned shortcut cannot be switched to; the menu and Settings both say so. This is why
  the app needs Accessibility permission.
- **Windows** — `WindowLister` reads on-screen window bounds via `CGWindowListCopyWindowInfo` (on-screen only means
  the current Space, and needs no permission); `TerminalWindows` builds the iTerm2 and Chrome AppleScript;
  `AppleScriptRunner` runs it. Saved frames are stored back-to-front because `framesToOpen` takes the suffix of the
  list, so reopening when some windows already exist adds the frontmost ones.

`Project` is the per-Space record, keyed to a Space by `spaceUUID`; `ProjectStore` enforces one project per Space and
persists to `~/Library/Application Support/uk.co.29degrees.projects/projects.json`, moving an undecodable file aside.
`Project`'s custom `init(from:)` exists purely to derive `openTerminals`/`openChrome` for records written before
those flags — keep it working when adding fields.

## Conventions and traps

- Tests use **swift-testing** (`import Testing`, `@Test`, `#expect`), not XCTest.
- The test bundle is hosted by the app, so a test run launches it. `AppState.start()` returns early under
  `isRunningTests` to avoid registering a login item and a global hotkey on the test machine. Anything with a
  machine-wide side effect belongs behind that guard.
- The project builds in **Swift 5 language mode**. A default argument is evaluated in a synchronous nonisolated
  context even inside an `@MainActor` type, so `AppState.init` takes `nil` for its `@MainActor` dependencies and
  resolves them in the body. Do the same for new ones (there is a comment at the call site explaining it).
- `overlayDuration` and `launchAtLogin` read state outside the class (`UserDefaults`, `SMAppService`), so
  `@Observable` does not track them; views hold their own `@State` and seed it in `onAppear`.
- `OverlayPanel` sets `hosting.sizingOptions = [.intrinsicContentSize]` only. Adding `.minSize`/`.maxSize` makes the
  hosting view and the hand-set panel size fight until AppKit throws on too many constraint passes.
- Signing: `app/Config.xcconfig` `#include?`s a git-ignored `app/Local.xcconfig` for `DEVELOPMENT_TEAM`. Never commit a
  team ID to the project file.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

README.md documents these scripts for a person setting the repository up. `raycast/` is an npm workspace of the root
package, so `npm install` at the root installs the extension's dependencies.

```sh
npm test                   # both suites
npm run app:test           # the Swift suite alone
npm run app:build          # build the app without running tests
npm run raycast:test       # the extension's Node suite alone
npm run raycast:typecheck  # tsc over the extension
npm run raycast:dev        # install the extension into Raycast, then rebuild on every save
```

`npm test` runs `scripts/test.mjs`, a harness over both suites rather than either suite's own runner.
`scripts/test.mjs` prints one line per test and nothing else. Both suites
run even when the first one fails, and every failure is repeated at the end with its reason and its file and line.
`app:test` and `raycast:test` run `xcodebuild` and `node --test` unfiltered, for when `scripts/test.mjs` hides
something you need.

**`npm test` covers both suites, so `npm test` is the command to run before calling any change complete.** Run
`npm test`, read what it prints, and treat a change as unfinished until every line is a tick. A passing `app:test`
alone says nothing about the extension, and a passing `raycast:test` alone says nothing about the app.

`scripts/test.mjs` parses each suite's output separately, because swift-testing prints an issue line before the
failure line for the same test, while `node --test` emits TAP once its output is a pipe rather than a terminal. A
suite that exits non-zero without any parsed failure has its whole log printed, so a build error or a crash partway
through is never reduced to silence. A change to either suite's reporter is a change `scripts/test.mjs` has to follow.

The scripts pass no flags of their own. Call `xcodebuild` directly to add one, such as `-only-testing` for a single
suite:

```sh
xcodebuild test -project app/Projects.xcodeproj -scheme Projects -destination 'platform=macOS' \
  -only-testing:ProjectsTests/AppStateTests
```

## What is here

`app/` is a menu bar app with no Dock icon and no main window. It names macOS Spaces and, for each Space, reopens
saved iTerm2 window layouts and a Chrome window of URLs.

`raycast/` is a Raycast extension holding one command, which lists the named Spaces and switches to the one you pick.

README.md covers the user-facing behaviour and the macOS permissions. Read README.md before changing behaviour.

## Architecture: the app

`AppState` (`app/src/AppState.swift`) is the only stateful object. It is `@MainActor @Observable`, owns `ProjectStore`
and `ShortcutStore`, and every view reads `AppState` through `@Bindable`. `AppState.init` takes five seams, and every
call `AppState` makes to the system goes through one of them: `SpaceProviding`, `OverlayShowing`, the Mission Control
shortcut reader closure, `SpaceSwitching`, and `UserDefaults`. Tests substitute a fake for each of those five seams.
Put new system access behind the same pattern rather than calling into AppKit from `AppState`.

macOS publishes no API for any of the three things this app does, so each workaround is isolated in one file, and that
file's comments carry the detail:

- **Reading Spaces** — `SpaceProvider` loads a private SkyLight function at runtime. `SpaceList` turns what
  `SpaceProvider` returns into a `SpaceSnapshot`.
- **Switching Space** — `MissionControlShortcuts` reads the user's "Switch to Desktop N" key combos from a preference
  domain, and `SpaceSwitcher` posts one as a keystroke. A Space with no such shortcut cannot be switched to. Posting
  keystrokes is the only reason the app needs the Accessibility permission.
- **Opening windows** — `WindowLister` reads window bounds, `TerminalWindows` builds AppleScript for iTerm2 and
  Chrome, and `AppleScriptRunner` runs that AppleScript.

`Project` is the per-Space record, keyed to a Space by `spaceUUID`. `ProjectStore` enforces one project per Space and
persists to Application Support.

## Architecture: the extension

`raycast/` is a separate npm package written in TypeScript. Each of its three modules holds what can be tested to the
same degree:

- `src/spaces.ts` — filtering, sorting and sectioning, as pure functions over plain data. Covered by tests.
- `src/projects.ts` — the calls into the app, and the mapping from a failure to a message a person can act on.
- `src/switch-project.tsx` — the Raycast view. Raycast ships no headless harness, so logic placed in
  `switch-project.tsx` cannot be tested. Put logic in `spaces.ts` or `projects.ts`.

## How the two connect

`app/src/Scripting/` makes the app AppleScript-scriptable. `Projects.sdef` declares three commands — `list spaces`,
`switch to space` and `open space setup for` — and the extension calls them through `osascript` in JXA mode, which
returns the results as JSON.

The app answers every query from live state rather than from a cache, so the extension keeps none. Cocoa Scripting
constructs the `NSScriptCommand` subclasses itself, so they reach `AppState` through `AppDelegate.shared` rather than
by injection. The scripting entry points on `AppState` throw where the menu path shows an alert, because a modal
blocks the `osascript` process waiting for the reply.

`Projects.sdef` and `ScriptCommands.swift` carry comments recording what Cocoa Scripting requires of them. Read those
comments before changing either file. Breaking one of those requirements produces `-1708 Message not understood`, an
empty record, or a Foundation exception, none of which names the cause.

## Tests

Work test-first. Write the failing test, run it, confirm it fails for the reason you expect, then write the smallest
implementation that makes it pass. One test and one implementation per cycle. Do not write a batch of tests against
behaviour that does not exist yet: those tests pin the shape you imagined rather than the behaviour you end up with.

Test through the public interface. A test that reaches into private state fails when the code is refactored even
though the behaviour has not changed.

An assertion must not recompute its expected value the way the implementation computes it, because such a test agrees
with the code by construction. Use a literal or a worked example instead.

Three paths cannot be tested and must not be faked to look tested. `SpaceSwitcher.post` posts a real CGEvent and
switches the Space of whoever runs the suite. `AppleScriptRunner` drives iTerm2 and Chrome. Raycast provides no
headless harness for a command view. Keep logic out of those paths so the logic stays testable: `SpaceList.parse`,
`TerminalWindows.framesToOpen`, `AppState.scriptableSpaces` and `raycast/src/spaces.ts` all exist for that reason.

## Conventions

- Swift tests use swift-testing (`import Testing`, `@Test`, `#expect`), not XCTest.
- The test bundle is hosted by the app, so a test run launches the app. `AppState.start()` returns early under
  `isRunningTests`. Put anything with a machine-wide side effect behind that guard.
- The project builds in Swift 5 language mode, where a default argument is evaluated outside the enclosing type's
  actor. `AppState.init` therefore takes `nil` for its `@MainActor` dependencies and resolves them in the body. Give
  any new `@MainActor` dependency the same treatment.
- `@Observable` tracks stored properties only, so a value read from `UserDefaults` or `SMAppService` does not trigger
  a view update. A view showing such a value holds its own `@State` and seeds that `@State` in `onAppear`.
- `grep` in this shell resolves to `ugrep -G`, which rejects some patterns a reader expects to work. Use
  `command grep` or the Grep tool.
- `swift-format` is not on `PATH`. Run `xcrun swift-format`, and add `--recursive` when the argument is a directory.
- There is no linter. `app/src/` and `app/tests/` are `PBXFileSystemSynchronizedRootGroup`s, so a new file is picked
  up by path. Never hand-edit `project.pbxproj` to add one.
- `app/Config.xcconfig` includes a git-ignored `app/Local.xcconfig` for `DEVELOPMENT_TEAM`. Never commit a team ID to
  the project file.

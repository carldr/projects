# Projects

Projects is a macOS menu bar app for people who keep one Space per project and run many Spaces.

You give each Space a name in the app. The menu bar item shows the number of the current Space and that name, for example "7 Website". When you switch Space, the Space's name appears in large white text in the middle of the primary display, then fades out. The menu lists every Space; clicking one switches to it.

For each Space you can save the positions of your iTerm2 windows and reopen them later in a chosen directory, and open a Chrome window with a list of URLs.

<p align="center"><img src="docs/images/menu.png" width="279" alt="The Projects menu: eleven named Spaces with the current one ticked, then Open space setup, Save iTerm2 windows, Settings and Quit"></p>

## Requirements

- macOS 14 Sonoma or later, with "Displays have separate Spaces" turned off in System Settings > Desktop & Dock. The app reads the Spaces of the first display only, so with "Displays have separate Spaces" on, the other displays' Spaces are misreported.
- Xcode 26 or later to build.
- iTerm2 and Google Chrome, for the window features.

Spaces are created in Mission Control (Control+Up, then the + at the top right). macOS numbers them left to right.

## Building and first run

Open `Projects.xcodeproj` and press Run. The menu bar item appears at once; the app has no Dock icon.

The project carries no signing team. Xcode signs the build to run locally, which is all the app needs. To sign with your own Apple Developer team instead, create a file named `Local.xcconfig` next to `Projects.xcodeproj` containing `DEVELOPMENT_TEAM = <your team ID>`; the file is git-ignored.

A Run build is enough to keep using the app. Archive only to install a copy outside Xcode: Product > Archive, Distribute App > Custom > Copy App, then move `Projects.app` to `/Applications`.

Sources are in `src/`, tests in `tests/`. Run the tests with Product > Test in Xcode, or:

```sh
xcodebuild test -project Projects.xcodeproj -scheme Projects -destination 'platform=macOS'
```

## Permissions

- Sending the keystrokes that switch Space needs the Accessibility permission. The app prompts the first time you click a Space in the menu.
- Opening iTerm2 and Chrome windows needs the Automation permission for each app. The app prompts on first use.

If you deny a prompt, or a grant stops working after a rebuild from Xcode, go to System Settings > Privacy & Security > Accessibility (or > Automation) and toggle Projects off and on.

## How switching works

The app switches Space by sending the keyboard shortcut macOS assigns to "Switch to Desktop N".

Those shortcuts are off by default. Enable them in System Settings > Keyboard > Keyboard Shortcuts > Mission Control. macOS lists one per Space that exists; desktops beyond 9 have no key assigned until you set one.

The app reads the shortcuts from the system. The Shortcuts tab in Settings shows them and warns "Not set — switching will not work" for any Space without one. To give a Space a shortcut, tick that Space's "Switch to Desktop N" entry in the Mission Control list and assign a key.

## Setting up a Space

Open Settings from the menu, or press Command+comma while the menu is open. The Spaces tab lists every Space; click one to edit it.

- Name: shown in the menu bar and the overlay. Left blank, the Space shows as "Desktop N".
- "Open iTerm2 windows" reveals a directory field (blank means your home folder), a "Save current windows" button, the count of saved windows, and "Forget".
- "Open Chrome window" reveals a list of URLs with add, remove and reorder. URLs must start with `http://` or `https://`.

Menu > "Save iTerm2 windows" records the position of every iTerm2 window on the current Space. It is enabled only when "Open iTerm2 windows" is on for that Space.

Menu > "Open space setup", or Control+Shift+= from anywhere, opens the saved iTerm2 windows in the directory and a Chrome window with the URLs. Opening the space setup again opens only what is missing. Control+Shift+= can be changed in Settings > Shortcuts.

## General settings

- Overlay duration slider, 0.3 to 5 seconds.
- Launch at login, on by default.

## Where data lives

Space setups are stored in `~/Library/Application Support/uk.co.29degrees.projects/projects.json`. If `projects.json` cannot be read, the app moves it aside as `projects.json.broken-<timestamp>` and starts empty.

## Caveats

- Finding the current Space relies on a private macOS function. A macOS update could break it, in which case the menu shows "–" and an empty list.
- Not built for the App Store: the app is unsandboxed and uses a private API.

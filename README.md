![Window Gaffer — bring the right window forward](Assets/WindowGaffer-Logo-Horizontal.svg)

<p align="center">
  <a href="https://gaffer.vbd.sh/">Website</a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="DEVELOPMENT.md">Development guide</a>
</p>

---

Most switchers stop at the application. Window Gaffer goes straight to the
window you meant — the project, terminal, game, conversation, or dashboard you
want right now.

Give a window a shortcut, leave a compact label at the edge of the screen, or
use both. One action brings that window to the front while the rest of your
workspace stays exactly where it was.

## Built for window-heavy workflows

- **One command, one exact window.** Skip app-level cycling and focus the
  registered window directly.
- **Clickable overlays across Spaces.** Keep small text or emoji markers within
  reach, including over full-screen applications.
- **Global hotkeys.** Call a window without looking away from what you are
  doing.
- **Profiles for every context.** Switch complete sets of windows, labels, and
  shortcuts for work, focus, or play.
- **A layout that stays yours.** Drag, dock, align, resize, rename, and lock
  overlays in place.
- **Automatic reconnection.** If a target disappears, its marker stays muted
  and reconnects when the window returns.

## How it works

1. Open Window Gaffer from the menu bar and choose a window.
2. Keep its suggested name or replace it with your own text or emoji.
3. Assign a global hotkey, enable a clickable overlay, or use both.
4. Click the marker or press the shortcut whenever that exact window should
   come forward.

Turn on **Edit Overlays** to arrange and resize labels. Turn it off to lock the
layout and make every click focus its linked window. The built-in **Default**
profile works immediately; creating more profiles is optional.

## Private by design

> No screenshots. No stored pixels.

Window Gaffer uses macOS Accessibility to list and focus ordinary windows.
Screen Recording permission is not required for switching. The optional
**Detailed Window Names** permission reads window metadata for applications
that hide useful titles, but Window Gaffer never captures or stores their
contents.

For runtimes such as Wine that do not register as ordinary macOS applications,
Window Gaffer reads CoreGraphics metadata only: process ID, bounds, and name.

## Build from source

Window Gaffer currently targets **macOS 27** and requires **Xcode 27** with the
macOS 27 SDK.

```sh
./Scripts/build-app.sh
open ".build/Window Gaffer.app"
```

On first launch, grant access in **System Settings → Privacy & Security →
Accessibility**.

Run the core test suite with:

```sh
swift test
```

## Development

Window Gaffer is a Swift Package with a native AppKit/SwiftUI application and a
small platform-independent core:

| Path | Purpose |
| --- | --- |
| `Sources/WindowGaffer` | macOS application, window discovery, overlays, hotkeys, and UI |
| `Sources/WindowGafferCore` | matching, snapping, sizing, and persistence behavior |
| `Tests/WindowGafferCoreTests` | automated core tests |
| `Configuration/Info.plist` | application bundle metadata |
| `Assets` | app, menu-bar, and brand artwork |
| `Scripts` | reproducible build and asset utilities |
| `website/dist` | deployable static product website |

See [DEVELOPMENT.md](DEVELOPMENT.md) for repository conventions, generated
files, website packaging notes, and verification commands.

---

<p align="center"><strong>Stop searching. Call the window.</strong></p>

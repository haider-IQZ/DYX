# DYX

Linux download managers kept showing up dressed like a committee compromise from 2009, so this repo is the correction.

`DYX` is a desktop app for `axel` with:

- `Zig` doing the real download/backend work
- `Qt 6 + QML` handling the native shell

## What Lives Here

- `src/`
  The Zig backend. This is the part that actually talks to `axel`, tracks downloads, saves settings/history, and emits events.
- `qt/`
  The native shell and backend bridge. This is the app path that `nix run` builds now.
- `build.zig`
  Backend-only Zig build file. The downloader core still lives here.

## Run It

The civilized way:

```bash
nix run "path:$PWD"
```

That should build and launch the packaged Qt app with the Zig backend wired in.

## Work On It

Enter the shell:

```bash
nix develop "path:$PWD"
```

Build the backend:

```bash
zig build backend
```

Run backend tests:

```bash
zig build test
```

Build the native Qt shell:

```bash
cmake -S qt -B build/qt -G Ninja
cmake --build build/qt
./build/qt/dyx-qt
```

## Stack

Current live stack:

- `Zig`
- `Qt 6`
- `QML`
- `axel`
- `Nix`

## Wayland

Wayland vs X11 is now mostly a Qt question, which is already an improvement for everyone involved.

## Why Axel

Because `axel` already knows how to do the hard part, and I would rather build a good app around a proven downloader than spend six months reinventing a less reliable one out of ego.

## Status

This is alpha software, but it is real alpha software:

- downloads work
- pause/resume works
- delete cleans up partials and `.st` files
- settings and history persist
- the Qt shell compiles and packages

Which is honestly more than can be said for a lot of desktop apps that claim to be finished.

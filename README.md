# DYX

Linux download managers kept showing up dressed like a committee compromise from 2009, so this repo is the correction.

`DYX` is a desktop app for `axel` with:

- `Zig` doing the real download/backend work
- `Tauri + Rust` handling the native shell
- `React + Vite` rendering the UI you actually wanted instead of whatever beige tragedy shipped by default

## What Lives Here

- `src/`
  The Zig backend. This is the part that actually talks to `axel`, tracks downloads, saves settings/history, and emits events.
- `src-tauri/`
  The native shell and backend bridge.
- `components/`, `hooks/`, `lib/`, `public/`, `src/`, `styles/`
  The real frontend. This is the app now, not a side experiment in a nested folder.
- `build.zig`
  Backend-only Zig build file. We are not pretending the old webview shell still matters.

## Run It

The civilized way:

```bash
nix run "path:$PWD"
```

That should build and launch the packaged Tauri app with the Zig backend wired in.

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

Run the UI in the browser if you just want frontend iteration:

```bash
npm install
npm run dev
```

Run the actual desktop app in dev mode:

```bash
npm run tauri:dev
```

## Stack

Yes, it is a little unholy:

- `Zig`
- `Rust`
- `Tauri`
- `Vite`
- `React`
- `axel`
- `Nix`

But it works, and at this point I care more about the app feeling good than winning a purity contest against my own toolchain.

## Wayland

Linux graphics remains emotionally unstable, so the app defaults to the safer X11 path unless you explicitly opt into Wayland.

Try Wayland if you want:

```bash
DYX_EXPERIMENTAL_WAYLAND=1 npm run tauri:dev
```

Or for the packaged app:

```bash
DYX_EXPERIMENTAL_WAYLAND=1 nix run "path:$PWD"
```

If it feels silky smooth, congratulations.

If it detonates visually, that is why the fallback exists.

## Why Axel

Because `axel` already knows how to do the hard part, and I would rather build a good app around a proven downloader than spend six months reinventing a less reliable one out of ego.

## Status

This is alpha software, but it is real alpha software:

- downloads work
- pause/resume works
- delete cleans up partials and `.st` files
- settings and history persist
- the UI is no longer a cry for help

Which is honestly more than can be said for a lot of desktop apps that claim to be finished.

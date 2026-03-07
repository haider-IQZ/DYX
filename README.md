# DYX

A clean desktop wrapper for `axel`, because apparently Linux download managers heard "design" and took it as a personal insult.

This exists because I got tired of download apps that look like they were last loved during a kernel mailing list argument. So this one is fast, dark, sharp, and actually pleasant to use.

## What It Is

`DYX` is a Linux desktop app built with:

- `Zig` for the backend
- `webview` for the native desktop window
- `React + Vite + TypeScript` for the UI
- `axel` for the actual downloading part, because reinventing a battle-tested downloader would be fake productivity
- `Nix` so the setup is less "works on my machine" and more "works because the machine was forced to behave"

## Features

- Multi-connection downloads powered by `axel`
- Real-time speed, ETA, and downloaded size
- Pause, resume, retry, and delete
- Partial download recovery with `.st` sidecar support
- Remembers history and settings
- Clean UI instead of the usual Linux "suffering is a feature" aesthetic

## Run It

The normal way:

```bash
nix run "path:$PWD"
```

That is the path that should feel nice and civilized.

## Build It

If you want the package output:

```bash
nix build "path:$PWD"
```

Then run:

```bash
./result/bin/dyx
```

## Dev

Enter the dev shell:

```bash
nix develop "path:$PWD"
```

Run the app from source:

```bash
zig build run
```

If you want frontend hot reload too:

```bash
cd ui
npm install
npm run dev
```

And in another terminal:

```bash
nix develop "path:$PWD" -c env DYX_UI_DEV_URL=http://127.0.0.1:5173 zig build run
```

## Wayland

By default the packaged app uses the stable X11 path, because embedded WebKit on Wayland decided to be dramatic.

If you want to try the experimental Wayland route anyway:

```bash
DYX_EXPERIMENTAL_WAYLAND=1 nix run "path:$PWD"
```

If it behaves beautifully, great.

If it explodes aesthetically or spiritually, that is why X11 is still the default.

## Why Axel

Because `axel` is fast, proven, and already good at the hard part.

This app is the "give it a proper UI and stop making me babysit a terminal" layer.

## Current Status

It is very much real software now:

- downloads actually work
- pause/resume actually work
- delete cleans up files and `.st`
- closing the app does not silently pretend everything is fine

Which, for a desktop app project, is honestly already a small miracle.

## License

Do whatever makes sense for the repo owner here.

Right now this README is more emotionally committed than legally committed.

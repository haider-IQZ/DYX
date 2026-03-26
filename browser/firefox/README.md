# Firefox Extension

This extension automatically catches normal HTTP/HTTPS downloads in Firefox and hands them to DYX over Firefox native messaging.

Runtime handoff:

`Firefox -> dyx-native-host -> dyx-relay -> running DYX`

`DYX` is single-instance, so an already-open app receives the download instead of a second GUI window being launched.

It now focuses on automatic catch only:

- click-intent capture for obvious file links and mild download-like anchors
- earlier interception for attachment downloads and safe download-like Firefox request types
- browser download fallback stays enabled for cases the early path misses
- some real Firefox download flows are not labeled `main_frame`, so DYX also considers safe `other` request types
- `object` requests are logged for diagnosis but are not auto-caught yet
- random site assets, API endpoints, sprites, SVG internals, inline media, and page internals are intentionally excluded from auto-catch

## Dev Setup

1. Build the native host and helper scripts:

```bash
zig build backend
```

2. Register the Firefox native host:

```bash
./zig-out/bin/dyx-register-firefox-host
```

3. Build the Qt app if you want DYX to launch from the repo:

```bash
cmake -S qt -B build/qt -G Ninja
cmake --build build/qt
```

4. Open Firefox:
   - `about:debugging#/runtime/this-firefox`
   - `Load Temporary Add-on...`
   - choose [manifest.json](/home/soka/projects/DYX/browser/firefox/manifest.json)

## Current Scope

- Firefox on Linux
- automatic catch only
- request-first interception with browser-intent hints
- replayable native handoff with optional filename, referrer, user-agent, replay headers, and correlation metadata
- browser-only fallback for non-replayable flows such as incognito, non-GET exports, and other Firefox-only download paths
- private/incognito downloads are ignored
- `save image as` is still best-effort, not guaranteed-perfect
- Firefox catcher logs are written to `~/.local/share/DYX/logs/firefox-catcher/`

## Disable / Re-enable

Click the toolbar button to toggle the catcher on or off.

## Remove Host Registration

```bash
./zig-out/bin/dyx-unregister-firefox-host
```

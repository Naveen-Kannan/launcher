# launcher

Minimal app launch and focus commands for [hkd](https://github.com/Naveen-Kannan/hotkey).

The motivation is the same as `hotkey` and `tiler`: explicit commands, no extra process,
no polling, and near-zero idle overhead. `launcher` is a Swift Package library that plugs
into `hkd`, which already owns hotkeys, IPC, config reload, and permissions.

## Commands

| Command | Action |
|---|---|
| `app.term` | Activate term (Alacritty) |
| `app.chrome` | Activate Google Chrome |
| `app.outlook` | Activate Microsoft Outlook |
| `app.messages` | Activate Messages |
| `app.notes` | Activate Notes |
| `app.cursor` | Activate Cursor |
| `app.codex` | Activate Codex |
| `app.muse` | Activate Muse |
| `app.antigravity` | Activate Antigravity |
| `app.tunes` | Activate tunes |
| `tunes.play_pause` | Send play/pause to tunes |
| `tunes.next` | Send next-track to tunes |
| `tunes.previous` | Send previous-track to tunes |
| `app.search` | Toggle the app search panel (Spotlight replacement for apps) |

## Integration

`launcher` is imported by `hkd` as a SwiftPM dependency.

To wire up sample bindings, add entries like these to `~/.config/hkd/config.json`:

```json
{
  "bindings": [
    { "trigger": "ctrl+cmd+t", "on_press": "app.term" },
    { "trigger": "ctrl+cmd+g", "on_press": "app.chrome" },
    { "trigger": "ctrl+cmd+o", "on_press": "app.outlook" },
    { "trigger": "ctrl+cmd+m", "on_press": "app.messages" },
    { "trigger": "ctrl+cmd+n", "on_press": "app.notes" },
    { "trigger": "ctrl+cmd+c", "on_press": "app.codex" },
    { "trigger": "ctrl+cmd+s", "on_press": "app.muse" },
    { "trigger": "ctrl+cmd+a", "on_press": "app.antigravity" },
    { "trigger": "ctrl+cmd+u", "on_press": "app.tunes" },
    { "trigger": "ctrl+cmd+space", "on_press": "tunes.play_pause" },
    { "trigger": "ctrl+cmd+right", "on_press": "tunes.next" },
    { "trigger": "ctrl+cmd+left", "on_press": "tunes.previous" }
  ]
}
```

## How It Works

- `LauncherCommands` exports a flat `[String: () -> Void]` command map
- `hkd` registers the commands once at startup
- Each handler resolves a concrete app target and asks `NSWorkspace` to open it with activation
- If the app is already running, macOS shifts focus to it; otherwise it launches and activates it
- Tunes control commands post a localhost request to the running tunes app, so playback control stays app-specific and does not need focus

`tunes` first resolves by bundle identifier, then falls back to the sibling repo build output at
`../tunes/electron-tunes/dist/mac-arm64/Electron Tunes.app`.

Tunes resolves by bundle ID first and uses `/Applications/Electron Tunes.app` as its
fallback. A fallback must reference the installed app, rather than a build-time source
checkout. Run `swift test` for the target regression check.

## App search

`app.search` replaces Spotlight for opening apps. Spotlight's app results come from the same index as every file, so they show up late, mix with files and web results, and disappear when the index rebuilds.

- **Own index.** Scans `/Applications` (and one folder level below it), `/System/Applications`, CoreServices, the Safari cryptex and `~/Applications`, and watches those folders. Rebuilt in the background on change. No Spotlight involved.
- **Ranking** in tiers: exact, then prefix, then word start (`code` → Visual Studio Code), then initials (`vsc`), then scattered letters. Within a tier, frecency breaks ties (10-day half-life). The last app you picked for a typed prefix ranks first next time, so `s` → Safari once you've picked it.
- **Panel.** Non-activating, built on first use and then only shown and hidden. ↑↓ / ⌃N⌃P / Tab to move, Return to open, ⌘1–9 to open by position, ⌘Return to reveal in Finder, Esc or click away to close. An empty query lists your most-used apps.
- **State.** `~/Library/Application Support/launcher/frecency.json` stores bundle IDs, counts, and prefix → bundle ID.

hkd should call `LauncherCommands().start()` at launch so the index is built before the first search. Bind it with `{ "trigger": "cmd+space", "on_press": "app.search" }` after turning off Spotlight's shortcut (System Settings › Keyboard › Keyboard Shortcuts › Spotlight).

Nuance: this gives hkd a real (lazy) window. The panel becomes key without activating any app, and focus returns to the app underneath on close.

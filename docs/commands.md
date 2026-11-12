---
title: Commands and keybinds
sidebar_position: 4
---

All commands are client-side and require no permission.

| Command | Arguments | Effect |
| --- | --- | --- |
| `/refreshskin` | none | Loads the saved appearance from the server again and applies it (the same as the `reloadSkin` export). |
| `/c` | `part` | Quick clothing toggle. Takes one item off or puts it back, `reset` / `all` puts everything back. The name comes from `Config.quickToggle.command` and the command exists only if `Config.quickToggle.enabled`. See [Quick toggles](./features/quick-toggles.md). |

The `/c` chat suggestion lists every part ID and the reset words (`Config.quickToggle.chatSuggestion`).

## Keybinds

| Name | Default key | Exists when | Effect |
| --- | --- | --- | --- |
| `kora_clothing_open_shop` | `E` | `Config.interactionMode = 'textui'` | Opens the shop whose prompt is showing. Registered through kora_lib `Kora.keybind`, so players can rebind it. |

## In the menu

| Input | Effect |
| --- | --- |
| Left or right mouse drag over the character | Rotate (see [Camera and rotation](./features/camera.md)) |
| Mouse wheel over the character | Zoom |
| Mouse wheel or arrow keys over a column | Scroll the column |
| `Esc` | Cancel the session (not in mandatory character creation) |

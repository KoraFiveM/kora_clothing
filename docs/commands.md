---
title: "Commands"
sidebar_position: 4
---


# Commands

Two chat/console commands. The quick-toggle command's name is configurable; `/refreshskin` is fixed.

## Built-in commands

### `/c <part>`

Takes one clothing part off (vest, shirt, pants, shoes, hat, mask, visor, glasses, bag, chain, ears, watch, bracelet) and, on a second use of the same part, puts back exactly what was worn. `reset`/`all` (configurable via `Config.quickToggle.resetWords`) restore everything.

| Field | Details |
| --- | --- |
| Context | In-game · client command (name set by `Config.quickToggle.command`, default `c`) |
| Arguments | part — required. One of the ids/aliases in `Config.quickToggle.parts`, or a reset word. |
| Access | Any player, subject to `Config.quickToggle.allowDead`/`allowCuffed`/`allowInVehicle` and a per-use cooldown (`Config.quickToggle.cooldownMs`, default 1500ms). |

**Example**

```text
/c vest
/c reset
```

**Result**

The item is removed (or restored) with a short clothing animation (unless `Config.quickToggle.animations` is off). Purely client-local; never persisted or sent to the server.

### `/refreshskin`

Re-applies the citizen's saved skin from the database to the live ped. Same effect as the `reloadSkin` export.

| Field | Details |
| --- | --- |
| Context | In-game · client command |
| Arguments | None. |
| Access | Any player. |

**Example**

```text
/refreshskin
```

**Result**

The ped's appearance is reset to whatever `playerskins` currently holds for this citizen.

## Command summary

All commands are client-side and require no permission.

| Command | Arguments | Effect |
| --- | --- | --- |
| `/refreshskin` | none | Loads the saved appearance from the server again and applies it (the same as the `reloadSkin` export). |
| `/c` | `part` | Quick clothing toggle. Takes one item off or puts it back, `reset` / `all` puts everything back. The name comes from `Config.quickToggle.command` and the command exists only if `Config.quickToggle.enabled`. See [Quick toggles](./features/quick-toggles.md). |

The `/c` chat suggestion lists every part ID and the reset words (`Config.quickToggle.chatSuggestion`).

### Keybinds

| Name | Default key | Exists when | Effect |
| --- | --- | --- | --- |
| `kora_clothing_open_shop` | `E` | `Config.interactionMode = 'textui'` | Opens the shop whose prompt is showing. Registered through kora_lib `Kora.keybind`, so players can rebind it. |

### In the menu

| Input | Effect |
| --- | --- |
| Left or right mouse drag over the character | Rotate (see [Camera and rotation](./features/camera.md)) |
| Mouse wheel over the character | Zoom |
| Mouse wheel or arrow keys over a column | Scroll the column |
| `Esc` | Cancel the session (not in mandatory character creation) |

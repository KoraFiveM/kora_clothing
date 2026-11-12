---
title: Camera and rotation
sidebar_position: 2
---

The fitting-room camera (`client/camera.lua`) frames the character while a menu is open. Drag-to-rotate input is handled by the NUI and `client/rotate.lua`.

## Presets and starting view

The toolbar at the top of the menu switches between the presets in `Config.camera.zones`: Full body, Face, Torso, Legs and Shoes. Choosing a preset discards any wheel zoom. Changes of view ease over `Config.camera.transitionMs`.

- The camera opens in front of the character, face-on (`Config.camera.initialView = 'front'`), framing `Config.camera.initialPreset` (default `full`). `'current'` uses the older start at orbit angle 0, which is often side-on.
- With `Config.camera.frameToBones` (default on), the face and shoes presets are centred on the `SKEL_Head` and foot bones (`track` and `trackOffset`), so they fit any model or height.
- The camera never goes lower than `Config.camera.minHeightAboveGround` (0.15 m) above the floor.
- Choosing a menu category does not move the camera unless `Config.camera.resetOnCategoryChange = true`. In that case the category's entry in `Config.camera.categoryZones` is used.

## Holding still

With `Config.camera.holdStill` (default on), while a menu is open:

- the ped's idle animations are paused, and it is given a stand-still task with head IK turned off, so it does not turn to look at the camera
- the camera aims at one measured position (taken when the menu opens and again if the model changes) instead of following bones each frame

Both are restored on close. `false` keeps the older per-frame tracking.

## Zoom

The mouse wheel zooms continuously as an offset on top of the selected preset. `Config.camera.zoom.step` is metres per wheel notch, and the resulting radius is clamped between `min` (0.45) and `max` (4.5). The NUI sends wheel notches, not pixel deltas.

## Obstructions

Before the camera settles, a capsule shape test runs from the point the camera aims at to the camera position. If anything blocks it, the camera tries angles around the character in this order: 0, ±28°, ±55°, ±82° (raised), 180° (raised). Only angles up to `Config.camera.occlusionMaxSwing` (default 55°) are tried, so with the default the camera stays in front of the character. If no angle is clear, the camera pulls in to just short of the obstruction, never closer than `zoom.min`. The check runs again on a separate thread whenever the zone or zoom changes.

## Rotating

Hold the left mouse button (or the right, unless `Config.rotateRightButton = false`) over the character and drag. `Config.rotateInvert` reverses the direction. By default (`Config.rotateTurnsPed`) the drag turns the **character** while the camera stays where it is, so rotating cannot swing the camera through a wall. The original heading is restored when the menu closes. With `false`, the camera orbits the character instead.

The mode is `Config.rotateModeByService[service]` if set, otherwise `Config.rotateMode` (default `'capture'`). It is read each time a menu opens.

| Mode | Behaviour |
| --- | --- |
| `capture` | Default. Lua reads `GetNuiCursorPosition` every frame while the button is held, turns the character, and pulls the cursor back to the centre once it is 8% of the screen away. The cursor is hidden and returns to where the drag started. The drag ends on release, blur, Escape, menu close or `Config.rotateControlsMaxSeconds`. If the cursor natives are missing, it falls back to the NUI drag. |
| `plain` | Ordinary NUI drag using `movementX`, one `kora_clothing:nui:rotate` message per frame. Lua never moves the cursor. The cursor stops at the screen edge and can leave a windowed game. |
| `pointer` | Requests browser pointer lock (`Config.rotatePointerLock`). FiveM refuses it, so in practice this behaves like `recenter`. With `rotatePointerLock = false` it becomes `plain`. |
| `controls` | NUI focus drops the cursor (`SetNuiFocus(true, false)` with keep-input), and the mouse is read as `INPUT_LOOK_LR`. Ends on release, Backspace or Esc, `rotateControlsMaxSeconds`, or `rotateControlsIdleSeconds` after the mouse stops if the button cannot be seen. |
| `recenter` | NUI drag. Near a screen edge (`Config.rotateRecenterEdge`), the NUI asks Lua to move the cursor back to the centre. |

Cursor handling:

- `Config.rotateHideCursor` (default on) hides the cursor during a drag in every mode. The modes that move the cursor always hide it.
- `Config.rotateHideMethod`: `'blank'` swaps in a transparent cursor image (more reliable in FiveM). `'none'` uses CSS `cursor: none`.
- `Config.rotateDragCursor` (`'grabbing'` or `'hidden'`) applies only to `'plain'` drags with `rotateHideCursor` off.
- `Config.rotateRestoreCursor` puts a hidden cursor back where the drag began.
- `Config.rotateDragGuard` ends a drag when the release cannot be seen (cursor left the window, focus lost).
- `Config.rotateSensitivity` scales the 0.15 degrees per pixel used by plain, capture, pointer and recenter. `controls` uses `Config.rotateControlsSensitivity`.

## Menu scrolling and hint

The menu columns scroll with the mouse wheel anywhere over them, and with the arrow keys. The wheel never zooms the camera over a column. Scrollbars are hidden unless `Config.ui.showScrollbar = true`. A short controls hint shows when a menu opens (`Config.ui.showControlsHint`).

## Controls while a menu is open

All game controls are disabled except look left/right, look up/down and push-to-talk (control 249). The player is frozen in place.

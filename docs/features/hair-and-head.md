---
title: Hair, head and heritage
sidebar_position: 3
---

## Hair colour

Barber, hairdresser, character creation and admin sessions can set a **primary** and a **secondary (highlight)** hair colour, saved as `hairColor` and `hairHighlight`.

These are **palette indices, not RGB**. `SetPedHairColor` only accepts entries from the game's fixed hair palette. The client reads the real colour of each index with `GetPedHairRgbColor` and sends the palette with the session, and the NUI shows it as two swatch grids. The server clamps the indices to `0..63` (`Shared.maxHairColorIndex`), and the client clamps them again to the live `GetNumHairColors()`.

A clothing shop gets no palette. The server only accepts a hair colour change from services that may change component 2. A recolour-only visit is charged at the `body` (hair) price.

## Face and skin tone

In creation and admin sessions, the Face item (component 0) sets the head-blend face shape (drawable index, clamped to 0..45), and skin tone (0..45) can be changed. Both are creation-only.

## Heritage

With `Config.heritage.creator` (default on), creation and admin sessions show a Heritage panel. It lets the player choose a father and a mother for the face shape and for the skin, and a mix for each (0% all father, 100% all mother). The values are stored in the head table as `shapeFirst`, `shapeSecond`, `skinFirst`, `skinSecond` (-1 to 45, where -1 is "Auto") and `shapeMix`, `skinMix` (0 to 1). "Auto" uses the selected face and skin tone, which is also how characters saved before heritage existed look.

## Head overlays

| Overlay | GTA overlay | Saved keys | Max style | Palette |
| --- | --- | --- | --- | --- |
| Facial hair (`facialHair`) | 1 | `beard`, `beardOpacity`, `beardColor` | 28 | hair |
| Eyebrows (`eyebrows`) | 2 | `eyebrows`, `eyebrowsOpacity`, `eyebrowsColor` | 33 | hair |
| Chest hair (`chestHair`) | 10 | `chestHair`, `chestHairOpacity`, `chestHairColor` | 15 | hair |
| Make-up (`makeup`) | 4 | `makeup`, `makeupOpacity`, `makeupColor` | 74 | make-up (colour type 2) |
| Blush (`blush`) | 5 | `blush`, `blushOpacity`, `blushColor` | 6 | make-up |
| Lipstick (`lipstick`) | 8 | `lipstick`, `lipstickOpacity`, `lipstickColor` | 9 | make-up |

- Style -1 means none. Opacity is 0 to 1. Colour -1 means "not picked": hair-palette overlays then use the primary hair colour, and make-up overlays use palette entry 0.
- `Config.headOverlays.<key>.creator` and `.barber` decide where each overlay can be edited. Overlay changes at a barber are charged at the hair price. Disabled overlays are hidden in the menu and ignored by the server.
- `followHairColor` (eyebrows, facial hair, chest hair) hides that overlay's palette and always uses the primary hair colour. The stored colour is reset to -1.

## Menu text and languages

The hair, overlay, heritage and clothing-switch labels come from `locales/en.json` (`ui.*` keys) and are sent with each session. To translate them, add `locales/<language>.json` with the same `ui` keys. kora_lib chooses the language from the `kora_locale` convar and falls back to English for each missing key. Other menu text is fixed in the UI bundle.

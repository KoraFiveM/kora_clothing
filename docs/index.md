---
title: kora_clothing
sidebar_position: 1
---

kora_clothing is the clothing, appearance and outfit wardrobe resource for Kora FiveM servers. Players shop for clothes, get their hair cut, get tattooed and create their first character in one fitting-room menu (a React NUI). While a menu is open the player is moved into a private routing bucket (`Config.bucket.base + source`), so nobody else can see or interact with them, and a live camera frames the character. The current look is stored per citizen in `playerskins` and named outfits in `playeroutfits`. Purchases are priced on the server and paid through kora_core money. The resource `provide`s `qb-clothing` and uses the upstream qb-clothing event and callback names, so scripts written for qb-clothing keep working.

## Features

- **Fitting-room sessions**: clothing shops, barbers, hairdressers, tattoo studios, the personal wardrobe, the one-time character creation and an admin session share one menu. What each one may change is set per service in `Config.services`, and the server enforces it. See [Fitting-room sessions](./features/sessions.md).
- **Server-side pricing**: when a session is confirmed, the server compares the result with the saved appearance and charges once for each category that changed, plus a price for each added tattoo. Re-wearing an outfit you already saved is free.
- **Private routing bucket**: each session runs in its own bucket. Ambient population can be switched off for character creation.
- **Outfit wardrobe**: save named looks (up to `Config.wardrobe.maxOutfits`) and wear or delete them from the menu.
- **Character creation**: new characters start in a configurable starter outfit, and a mandatory free fitting opens after kora_multichar has finished the spawn. It covers face, heritage (mother and father), skin tone, hair, head overlays, clothing and tattoos.
- **Fitting-room camera**: preset framings (full body, face, torso, legs, shoes), mouse-wheel zoom, drag to rotate the character in several input modes, and an obstruction check so walls and counters do not block the view. See [Camera and rotation](./features/camera.md).
- **Hair colour and head overlays**: primary and highlight hair colour from the game palette, plus facial hair, eyebrows, chest hair, make-up, blush and lipstick. Each overlay has a style, opacity and colour, and you choose which ones are available in creation and at barbers. See [Hair, head and heritage](./features/hair-and-head.md).
- **Tattoo studio**: a tattoo catalogue set in the config with per-tattoo prices, stacking (the same tattoo applied more than once renders darker), preview-only undress buttons and an optional tattoo artist ped. See [Tattoo studio](./features/tattoos.md).
- **Preview clothing switches**: Hat, Shirt, Pants and Shoes switches (barbers and hairdressers by default) that only affect the preview. See [Preview clothing switches](./features/clothing-toggles.md).
- **Quick toggles**: `/c <part>` takes one clothing item off and puts it back without opening a menu. See [Quick toggles](./features/quick-toggles.md).
- **Shops and blips**: shops open from a text prompt (`[E] Open ...`, the default) or a kora_target zone. Clothing shops can open from register and rack areas, and decorative clerks are optional. Map blips are grouped by category. See [Shops and blips](./features/shops.md).
- **Clothing as items (optional)**: with this on, a purchase is given as a reusable `kora_clothing_outfit` inventory item instead of being put on straight away. See [Items](./items.md).
- **Closing on going down**: open menus are cancelled when the player enters last stand or dies.
- **Compatibility with qb-clothing, qb-multicharacter and qb-radialmenu**. See [Compatibility](./compatibility.md).

## Requirements

Hard dependencies (from `fxmanifest.lua`, `dependency` entries):

- [kora_theme](https://github.com/KoraFiveM/kora_theme): the client loads `@kora_theme/client/bridge.lua` for the menu theme
- [kora_lib](https://github.com/KoraFiveM/kora_lib): config descriptors, events, callbacks, zones, TextUI, keybinds, entities, blips, notifications, locales and cache
- [kora_sql](https://github.com/KoraFiveM/kora_sql): database access and the table schema
- [kora_core](https://github.com/KoraFiveM/kora_core): player data, money, permissions, routing buckets and shared item registration
- [kora_target](https://github.com/KoraFiveM/kora_target): shop zones and tattoo artist targets when `Config.interactionMode = 'target'`

Optional integrations:

- [kora_multichar](https://github.com/KoraFiveM/kora_multichar): starts the first-character fitting after the spawn and uses the character-select preview callback
- [kora_inventory](https://github.com/KoraFiveM/kora_inventory): needed only for `Config.clothingAsItem = true`
- [kora_hud](https://github.com/KoraFiveM/kora_hud): hidden while a menu is open and shown again afterwards. Without it, the radar is hidden instead (`Config.hideRadarInMenu`)
- [kora_ambulance](https://github.com/KoraFiveM/kora_ambulance): its `emsDown` player state bag closes menus during last stand
- [kora_police](https://github.com/KoraFiveM/kora_police): its `isHandcuffed` export blocks quick toggles while cuffed
- [kora_admin](https://github.com/KoraFiveM/kora_admin): opens admin appearance sessions through the `OpenAdminSession` server export

## Installation

1. Put the resource in your resources folder.
2. Ensure it after its dependencies in `server.cfg`. The `dependency` entries also enforce this start order:

```cfg
ensure kora_sql
ensure kora_lib
ensure kora_theme
ensure kora_core
ensure kora_target
ensure kora_clothing
```

3. No manual SQL import is needed. On start the resource creates or updates `playerskins` and `playeroutfits` through kora_sql's schema handler (`server/schema.lua`). See [Database](./database.md).
4. You do not need to add any items unless you turn on `Config.clothingAsItem`. In that case the resource registers the `kora_clothing_outfit` item with kora_core itself. You only provide the item image. See [Items](./items.md).
5. Review `config.lua`. Most settings are kora_lib config descriptors, so they can also be edited in kora_lib's config workspace. See [Configuration](./api/configuration.md).

## Documentation map

- [Installation](./installation.md): setup steps and the manifest reference
- [How to use](./how-to-use.md): shops, tattoo studio, character creation, wardrobe, quick toggles and driving it from other resources
- [Commands and keybinds](./commands.md): `/c`, `/refreshskin`, keybinds and menu inputs
- API reference: [overview](./api/index.md), [client exports](./api/exports-client.md), [server export](./api/exports-server.md), [events, callbacks and the legacy qb-clothing protocol](./api/legacy-protocol.md), [configuration](./api/configuration.md) (every option in `config.lua`)
- Features: [sessions](./features/sessions.md), [camera](./features/camera.md), [hair and head](./features/hair-and-head.md), [tattoo studio](./features/tattoos.md), [preview switches](./features/clothing-toggles.md), [quick toggles](./features/quick-toggles.md), [shops and blips](./features/shops.md)
- [Database](./database.md)
- [Items](./items.md)
- [Compatibility](./compatibility.md)
- [Troubleshooting](./troubleshooting.md)

## Development notes

- `tests/*.feature` are Gherkin scenarios for kora_qa (`qa_feature` in the manifest). `test/` holds standalone Lua smoke tests (`test/run.sh`), and `web/src/lib/*.test.ts` are the UI unit tests.
- `fft_hooks.lua` and `fft_hooks_server.lua` are optional development hooks. They do nothing unless `setr fft_kora_hooks true` is set, and only the `fft` resource may call them.
- The NUI source is in `web/` and the built bundle in `web/build/` is what the manifest loads.

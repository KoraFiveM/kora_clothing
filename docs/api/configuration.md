---
title: "Configuration"
sidebar_position: 5
---


# Configuration

`Config` is a shared script (client and server both see it). Every setting is self-contained to this resource — it does not read `kora_core`'s shared registries. Settings wrapped in the local `boolean`/`config.*` helpers become live-editable in `kora_lib`'s config workspace when `kora_lib`'s config module is present, falling back to the plain default otherwise.

Namespace: `Config` · Source: `config.lua`

## Options

Pass an options table as the final argument to a play function. Omit the table or any field to use its default.

### Shops and service pricing

| Option | Type | Description |
| --- | --- | --- |
| `Config.shop.currency` | string | Currency key charged for every paid service. Default `'cash'`. |
| `Config.services` | table | Per-service (`clothing`, `barber`, `hairdresser`, `tattoo`, `creation`) component/prop whitelists and prices. `creation` is `{ all = true, tattoos = true }` — always free and unrestricted. |
| `Config.shops` | table[] | One entry per location: `service`, `free`, `label`, `ped` (clerk model), `coords` (vector4, heading in `.w`), `zone` (polygon or box), `blip`. Clothing shops may add `points = { register, racks }`. |
| `Config.shopZoneDefault` | table | Fallback `{ size }` box used when a shop entry has no `zone` of its own. |
| `Config.interactDistance` | number | Default 2.0. Server-side tolerance is this plus 1.0 metre. |
| `Config.interactionMode` | 'target' \| 'textui' | How a shop is opened. Default `'textui'`. Read once at resource start. |
| `Config.clothingShopPoints / clothingPointRadius` | boolean / number | Opens clothing shops from a radius (default 5.0m) around their register/rack points instead of the shop zone. |
| `Config.genderLockedSalons` | boolean | Off by default. Restricts barbers to male and hairdressers to female freemode models when on. |
| `Config.shopPeds / shopPedScopeRadius` | boolean / number | Decorative clerk peds, off by default; spawned client-locally within `shopPedScopeRadius` (75m) when on. |

### Tattoo studio

| Option | Type | Description |
| --- | --- | --- |
| `Config.tattoos` | table[] | The tattoo catalogue: `id, label, group, collection, male?, female?, price`. Entries missing one gender's overlay simply do not appear for that model. |
| `Config.tattoo.allowStacking / maxStack / stackPriceMultiplier` | boolean / integer(1–10) / number | Whether a tattoo can be applied more than once, the cap, and the price multiplier for extra instances. |
| `Config.tattoo.undress` | table | `enabled` (preview buttons), `previewInCreator`, `autoUndressOnOpen` (parts bared on open), `parts` (per-part male/female bare drawables and cleared prop slots). |
| `Config.tattoo.peds` | table | `enabled` (artist peds, default on), `alpha` (fade while in studio), `scopeRadius`, `model`, `scenario`. Per-shop overrides live on `Config.shops[n].tattooPed`. |
| `Config.tattooStrip` | table | Fixed per-gender bare drawables used when `undress.enabled` is off. |

### Fitting-room camera

| Option | Type | Description |
| --- | --- | --- |
| `Config.camera.zones` | table | Named camera presets (`full`, `face`, `torso`, `legs`, `shoes`): `boneOffset`, `camOffset`, `fov`, optional `track`/`trackOffset` to follow head/feet bones. |
| `Config.camera.categoryZones` | table | Maps a clothing/tattoo category name to the zone it frames when selected. |
| `Config.camera.holdStill / frameToBones / minHeightAboveGround` | boolean / boolean / number | Stops idle sway while a menu is open, frames face/shoes on real bones, and floor-clamps the camera. |
| `Config.camera.initialView / initialPreset` | 'front' \| 'current' / string | Starting orbit angle and zone when a menu opens. |
| `Config.camera.zoom` | table | `min`, `max`, `step` — free mouse-wheel zoom as an offset on top of the selected preset. |
| `Config.camera.orbitDegPerSec / transitionMs / occlusionMaxSwing` | number | Orbit speed (`orbitDegPerSec` is defined in `config.lua` but not read by any code, so it has no effect), view-change easing time, and how far the camera may swing to dodge an obstruction before it pulls in instead. |

### Rotate drag

| Option | Type | Description |
| --- | --- | --- |
| `Config.rotateMode / rotateModeByService` | 'plain'\|'capture'\|'pointer'\|'controls'\|'recenter' | How drag-to-rotate reads the mouse; default `'capture'` (hidden cursor held at screen centre). Per-service override for clothing/barber/hairdresser/tattoo/creation. |
| `Config.rotateTurnsPed` | boolean | Default true: dragging turns the character, not the camera, so the camera can never swing through a wall. |
| `Config.rotateSensitivity / rotateInvert / rotateRightButton` | number / boolean / boolean | Drag speed, direction and whether the right mouse button also rotates. |
| `Config.rotatePointerLock / rotateDragGuard / rotateRestoreCursor` | boolean | Mouse capture during drag, ending a drag if the release can't be observed, and returning the cursor to where the drag began. |

### Quick toggle (/c)

| Option | Type | Description |
| --- | --- | --- |
| `Config.quickToggle.enabled / command / chatSuggestion` | boolean / string / boolean | Master switch, command name (default `c`), and whether it appears in chat suggestions. |
| `Config.quickToggle.cooldownMs` | integer | Minimum time between two uses by one player, default 1500ms. |
| `Config.quickToggle.allowDead / allowCuffed / allowInVehicle` | boolean | Whether the command works in each state. |
| `Config.quickToggle.parts` | table[] | One entry per argument: `id`, `aliases`, male/female bare component list, cleared prop slots, and an optional clothing animation. |
| `Config.quickToggle.visor` | table | Per-gender map of a helmet drawable to its visor-swapped counterpart, used by `/c visor`. Empty by default — fill in for your clothing pack's helmets. |

### Wardrobe, starter outfit and misc

| Option | Type | Description |
| --- | --- | --- |
| `Config.starterOutfit` | table | `enabled` (default true) plus per-gender starter components/props a brand-new character spawns in. |
| `Config.wardrobe.maxOutfits` | integer | Default 20 saved outfits per citizen. |
| `Config.clothingAsItem / clothingItem` | boolean / table | Off by default. When on, a confirmed purchase/save gives a `kora_clothing_outfit` inventory item instead of equipping directly; requires `kora_inventory` running. |
| `Config.heritage.creator` | boolean | Default true. Shows the mother/father head-blend panel in character creation only. |
| `Config.headOverlays` | table | Per-overlay (`makeup`, `blush`, `lipstick`, `eyebrows`, `facialHair`, `chestHair`) `creator`/`barber` visibility and an optional `followHairColor` lock. |
| `Config.loginColourReapply` | table | Re-applies saved hair/overlay colours a short time after login (`delays`, ms) because a spawn sequence can reset them. |
| `Config.closeWhenDowned` | table | `enabled` cancels an open menu when the player goes down/dies; `blockOpen` also refuses to open one while downed. |
| `Config.ui.clothingToggles` | table | Preview clothing switches (Hat/Shirt/Pants/Shoes) shown in barber/hairdresser (and configurably other) menus; preview-only, never saved. |
| `Config.hideRadarInMenu` | boolean | Hides the minimap while any menu is open, when `kora_hud` is not running (kora_hud hides it itself otherwise). |

## Functions

Grouped by what each option affects.

## Limits and related APIs

Most settings marked `live` in the source re-read on next use (next session/drag/toggle) without a resource restart; `interactionMode`, `showTargetHints` and the quick-toggle command name are read once at resource start and need a restart to change.

## Full option reference

Every key in `config.lua` with its type and default, checked against the code.

All settings are in `config.lua` (shared, so the client and the server read the same table). Most entries are kora_lib config descriptors. When kora_lib's config module is loaded, `Kora.config.adopt(Config)` resolves them to plain values and makes them editable in kora_lib's config workspace. Settings marked **live** apply without a restart, at the moment noted in the description. Without the config module, the plain default after `or` is used.

### Routing bucket and population

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.bucket.base` | number | `1000000` | Each session runs in bucket `base + source`. |
| `Config.bucket.disablePopulation` | boolean | `true` | Turns ambient peds and vehicles off in the bucket, for the first-character fitting room only. Shop, barber and wardrobe sessions keep the population. Live, read on each fitting-room entry. |
| `Config.bucket.suppressClientPopulation` | boolean | `true` | During character creation, also sets this client's ped and vehicle population budgets to 0 and clears peds and vehicles within 80 m. The budgets go back to 3 when the fitting room closes. Live. |

### Money and services

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.shop.currency` | string | `'cash'` | kora_core money account charged for purchases. |
| `Config.services` | table | see below | Policy for each service: which components and props may change, prices, model restriction, tattoos. |
| `Config.wardrobe.maxOutfits` | number | `20` | Most saved outfits per citizen. |

`Config.services` keys are `clothing`, `barber`, `hairdresser`, `tattoo` and `creation`:

```lua
Config.services = {
    clothing = {
        components = { 3, 4, 5, 6, 7, 8, 9, 10, 11 }, -- component 1 (mask / facial hair assets) is excluded
        props = { 0, 1, 2, 6, 7 },
        prices = { tops = 175, legs = 150, shoes = 120, body = 90, accessories = 60 },
    },
    barber = { components = { 2 }, props = {}, model = 'male', prices = { body = 90 } },
    hairdresser = { components = { 2 }, props = {}, model = 'female', prices = { body = 90 } },
    tattoo = { components = {}, props = {}, tattoos = true },
    creation = { all = true, tattoos = true },
}
```

- `components` and `props` are allowlists of GTA component and prop IDs. When a session is confirmed, any ID not listed keeps its saved value.
- `prices` is keyed by category (`tops`, `legs`, `shoes`, `body`, `accessories`, see [Sessions](../features/sessions.md#pricing)). Each changed category is charged once. Hair colour and head overlay changes count as `body`.
- `model` (`'male'` or `'female'`) limits the service to one freemode model.
- `tattoos = true` lets the service change tattoos, priced per tattoo from `Config.tattoos`.
- `all = true` (creation) allows every component, prop, the face, skin tone and heritage.

### Character creation

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.starterOutfit.enabled` | boolean | `true` | A new character is reset to the starter outfit before the first spawn, so it never inherits the previous character's clothes. Live. |
| `Config.starterOutfit.male` / `.female` | table | see below | `components` and `props` maps of `{ d, t }` (drawable, texture) keyed by GTA ID. Unlisted components start on drawable 0. Unlisted props are removed. |
| `Config.heritage.creator` | boolean | `true` | Shows the Heritage panel (father and mother for face shape and skin, plus the mixes) in character creation and admin sessions. Live. |

Default starter outfit (both models): torso `3 = { d = 0 }`, legs `4 = { d = 0 }`, shoes `6 = { d = 1 }`, undershirt `8 = { d = 15 }` (none), top `11 = { d = 0 }` (plain t-shirt), no props. The face, skin tone and head overlays start on their defaults, with no tattoos.

### Head overlays

`Config.headOverlays.<key>` exists for `makeup`, `blush`, `lipstick`, `eyebrows`, `facialHair` and `chestHair`. All values are live.

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `<key>.creator` | boolean | `true` (all) | The overlay can be edited in character creation and admin sessions. |
| `<key>.barber` | boolean | `false` for makeup, blush, lipstick. `true` for eyebrows, facialHair, chestHair | The overlay can be edited at barbers and hairdressers, charged at the hair (`body`) price. |
| `<key>.followHairColor` | boolean | `false` | Only for `eyebrows`, `facialHair` and `chestHair`. When `true`, the overlay's palette is hidden and it always uses the primary hair colour. |

### Login colour re-apply

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.loginColourReapply.enabled` | boolean | `true` | After the saved skin is applied on login, the hair colour, highlight and overlay colours are applied again at each delay, because the spawn sequence can reset them. Skipped if a menu opens or the model changes. Live. |
| `Config.loginColourReapply.delays` | number list | `{ 750, 3000 }` | Milliseconds after the first apply. |

### Clothing as items

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.clothingAsItem` | boolean | `false` | When `true`, a paid purchase is given as a `kora_clothing_outfit` item instead of being put on. Requires kora_inventory. Read at resource start for item registration. |
| `Config.clothingItem` | table | see [Items](../items.md) | `name`, `label`, `weight`, `image`, `description` used to register the item. |

### Shops

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.shops` | list | 16 shops | Each entry is one service location. See [Shops and blips](../features/shops.md). |
| `Config.shopZoneDefault` | table | `{ size = vector3(2.0, 1.6, 2.2) }` | Box used for a shop entry without its own `zone`. |
| `Config.shopPeds` | boolean | `false` | Spawns a decorative clerk (`shop.ped`) per shop, client-local, only while the player is near it. |
| `Config.shopPedScopeRadius` | number | `75.0` | Distance at which the decorative clerk is created and removed. |
| `Config.interactDistance` | number | `2.0` | kora_target option range. The server accepts a shop session from inside the zone or within this distance plus 1 m of it. |
| `Config.clothingShopPoints` | boolean | `true` | Clothing shops that have `points = { register, racks }` open from a sphere around each of those points instead of the shop zone. Applies after a restart. |
| `Config.clothingPointRadius` | number | `5.0` | Radius of those spheres (1 to 15). The server allows this radius plus 1 m. Applies after a restart. |
| `Config.interactionMode` | enum | `'textui'` | `'textui'`: kora_lib TextUI `[E] Open <shop>` while inside the shop area. `'target'`: kora_target zone option. Applies after a restart. |
| `Config.showTargetHints` | boolean or nil | `nil` | Forces the kora_target world icon on shop zones on (`true`) or off (`false`). `nil` follows kora_target's own setting. Applies after a restart. |
| `Config.genderLockedSalons` | boolean | `false` | When `true`, barbers serve only male and hairdressers only female freemode models at shop visits. Live, read on each shop visit. |

### Tattoos

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.tattoos` | list | 16 base-game tattoos | Catalogue entries: `id`, `label`, `group` (`Head`, `Torso`, `Arms`, `Back`, `Legs`), `collection`, `male` / `female` overlay names, `price`. An entry without an overlay for a model is not shown for that model. |
| `Config.tattooStrip.male` / `.female` | map | see `config.lua` | Component ID to `{ d, t }` applied for a tattoo session when `Config.tattoo.undress.enabled = false`. Live. |
| `Config.tattoo.allowStacking` | boolean | `true` | Allows the same tattoo more than once. Live. |
| `Config.tattoo.maxStack` | integer | `3` | Most instances of one tattoo (1 to 10). The server enforces it. Live. |
| `Config.tattoo.stackPriceMultiplier` | number | `1.0` | Price factor for instances after the first (0 to 10). Live. |
| `Config.tattoo.undress.enabled` | boolean | `true` | Shows undress buttons in the studio. Live. |
| `Config.tattoo.undress.previewInCreator` | boolean | `true` | In character creation, choosing a tattoo temporarily removes the clothing over that body area. Live. |
| `Config.tattoo.undress.autoUndressOnOpen` | string list | `{ 'top', 'legs', 'headwear' }` | Part IDs removed when the studio opens. Live. |
| `Config.tattoo.undress.parts` | list | `top`, `legs`, `shoes`, `headwear` | One button per part: `id`, `label`, `male` / `female` lists of `{ id, d, t }` and `props` slots to clear. Live. |
| `Config.tattoo.peds.enabled` | boolean | `true` | Spawns a tattoo artist ped at every tattoo shop. Live. |
| `Config.tattoo.peds.alpha` | integer | `0` | Artist opacity (0 to 255) while the studio is open. Live. |
| `Config.tattoo.peds.scopeRadius` | number | `40.0` | Spawn distance (5 to 300). Live. |
| `Config.tattoo.peds.model` | string | `'u_m_y_tattoo_01'` | Fallback model when neither `shop.tattooPed.model` nor `shop.ped` is set. Live. |
| `Config.tattoo.peds.scenario` | string or nil | `'WORLD_HUMAN_STAND_IMPATIENT'` | Scenario the artist plays. Unset or `''` for idle. Live. |

### Menu (NUI)

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.ui.showControlsHint` | boolean | `true` | Shows a "Drag to rotate / Scroll to zoom" hint. It fades after the first rotate or zoom, or after about 8 seconds. Live. |
| `Config.ui.showScrollbar` | boolean | `false` | Draws scrollbars on the menu columns. They scroll with the wheel and arrow keys either way. Live. |
| `Config.ui.creatorOpensOnHair` | boolean | `true` | Character creation opens on Style, Hair. Live. |
| `Config.ui.clothingToggles.enabled` | boolean | `true` | Master switch for the preview clothing switches. Live. |
| `Config.ui.clothingToggles.services` | string list | `{ 'barber', 'hairdresser' }` | Menus that show them: `barber`, `hairdresser`, `clothing`, `creation`. Live. |
| `Config.ui.clothingToggles.items.hat` / `.shirt` / `.pants` / `.shoes` | boolean | `true` | Which switches are shown. Live. |
| `Config.ui.barberTopToggle` | boolean | unset | Legacy option, not in `config.lua`. If set to `false`, it still hides the Shirt switch. |
| `Config.hideRadarInMenu` | boolean | `true` | Hides the minimap while a menu is open, only when kora_hud is not running. Live. |

### Camera

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.camera.holdStill` | boolean | `true` | Pauses idle animations, gives the ped a stand-still task with head IK off, and aims at one measured position instead of following bones each frame. Live, read when a menu opens. |
| `Config.camera.frameToBones` | boolean | `true` | Frames the face and shoes presets on the head and foot bones. Live. |
| `Config.camera.minHeightAboveGround` | number | `0.15` | Lowest camera height above the floor, in metres (0 disables). Live. |
| `Config.camera.zones` | table | `full`, `face`, `torso`, `legs`, `shoes` | Framing presets: `boneOffset`, `camOffset`, `fov`, and optional `track` (`'head'` or `'feet'`) with `trackOffset`. |
| `Config.camera.zoom` | table | `{ min = 0.45, max = 4.5, step = 0.12 }` | Camera radius bounds and step per wheel notch, in metres. |
| `Config.camera.categoryZones` | table | see `config.lua` | Menu category or tattoo group to preset, used when `resetOnCategoryChange` is on. |
| `Config.camera.resetOnCategoryChange` | boolean | `false` | Moves the camera to the category preset when a category is selected. Live. |
| `Config.camera.initialView` | enum | `'front'` | `'front'` (face-on) or `'current'` (old angle-0 start). Live. |
| `Config.camera.initialPreset` | string | `'full'` | Starting preset. An unknown name falls back to `full`. Live. |
| `Config.camera.orbitDegPerSec` | number | `90.0` | Defined in the config but not read by the current code. |
| `Config.camera.transitionMs` | number | `500` | Time a change of view takes to settle (50 to 3000). Live. |
| `Config.camera.occlusionMaxSwing` | number | `55.0` | Furthest the camera may swing around an obstruction, in degrees (0 to 180). Live. |

Zone example:

```lua
face = { boneOffset = vector3(0.0, 0.0, 0.5), camOffset = vector3(0.0, 0.65, 0.0), fov = 30.0, track = 'head', trackOffset = 0.04 },
```

### Rotation

See [Camera and rotation](../features/camera.md) for how each mode behaves. All values are live.

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.rotateMode` | enum | `'capture'` | `'plain'`, `'capture'`, `'pointer'`, `'controls'` or `'recenter'`. |
| `Config.rotateModeByService` | table | all unset | Mode for each service (`clothing`, `barber`, `hairdresser`, `tattoo`, `creation`). Unset entries follow `Config.rotateMode`. |
| `Config.rotateTurnsPed` | boolean | `true` | A drag turns the character. `false` orbits the camera instead. |
| `Config.rotatePointerLock` | boolean | `true` | Only affects `'pointer'` mode. `false` turns `'pointer'` into `'plain'`. |
| `Config.rotateDragGuard` | boolean | `true` | Ends a drag when the mouse release cannot be seen (cursor left the window, blur). |
| `Config.rotateRestoreCursor` | boolean | `true` | The hidden cursor reappears where the drag started (`'plain'`, `'recenter'`, `'pointer'`. `'capture'` and `'controls'` always do this). |
| `Config.rotateSensitivity` | number | `1.0` | Multiplier on 0.15 degrees per pixel (plain, capture, pointer, recenter). |
| `Config.rotateRightButton` | boolean | `true` | The right mouse button also rotates. |
| `Config.rotateInvert` | boolean | `false` | Reverses the drag direction. |
| `Config.rotateHideCursor` | boolean | `true` | Hides the cursor while a drag is held. |
| `Config.rotateHideMethod` | enum | `'blank'` | `'blank'` (transparent image cursor) or `'none'` (CSS `cursor: none`). |
| `Config.rotateDragCursor` | enum | `'grabbing'` | Cursor during a `'plain'` drag when `rotateHideCursor` is off: `'grabbing'` or `'hidden'`. |
| `Config.rotateRecenterEdge` | number | `0.04` | `'recenter'` only: fraction of the screen from an edge that triggers a recentre. |
| `Config.rotateControlsSensitivity` | number | `8.0` | `'controls'` only: degrees per unit of mouse movement. |
| `Config.rotateControlsIdleSeconds` | number | `0.4` | `'controls'` only: ends the drag this long after the mouse stops, if the held button cannot be seen. |
| `Config.rotateControlsMaxSeconds` | number | `30.0` | `'controls'` and `'capture'`: hard limit for one drag. |

### Quick toggles

See [Quick toggles](../features/quick-toggles.md).

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.quickToggle.enabled` | boolean | `true` | Registers the command. Read at start. |
| `Config.quickToggle.command` | string | `'c'` | Command name. Read at start. |
| `Config.quickToggle.chatSuggestion` | boolean | `true` | Adds a chat suggestion. |
| `Config.quickToggle.cooldownMs` | integer | `1500` | Minimum time between uses (0 disables). Live. |
| `Config.quickToggle.allowDead` | boolean | `false` | Allows the command while dead. Live. |
| `Config.quickToggle.allowCuffed` | boolean | `false` | Allows the command while cuffed (checked through kora_police). Live. |
| `Config.quickToggle.allowInVehicle` | boolean | `true` | Allows the command in a vehicle. Live. |
| `Config.quickToggle.animations` | boolean | `true` | Plays each part's animation. Live. |
| `Config.quickToggle.animationsInVehicle` | boolean | `false` | Also plays the animation in a vehicle. Live. |
| `Config.quickToggle.resetWords` | string list | `{ 'reset', 'all' }` | Arguments that put everything back. Live. |
| `Config.quickToggle.visor` | table | `{ male = {}, female = {} }` | Pairs of hat drawables (visor up and down) for each gender. |
| `Config.quickToggle.parts` | list | 13 parts | `id`, `label`, `aliases`, `male` / `female` lists of `{ id, d, t }`, `props`, `visor`, `animDict`, `animClip`, `animMs`. Live. |

### Closing menus when the player goes down

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.closeWhenDowned.enabled` | boolean | `true` | Cancels open menus on last stand or death. Character creation is never cancelled. Live. |
| `Config.closeWhenDowned.blockOpen` | boolean | `true` | Refuses to open a menu while the player is downed or dead. Live. |
| `Config.closeWhenDowned.checkIntervalMs` | integer | `250` | Poll interval (minimum 50), used only when kora_lib has no cache module. |

### Test-only

`Config.testMode` is not in `config.lua`. The smoke tests set it to expose internal functions. Do not set it on a server.

## Related guides

- [Client exports](./exports-client.md)
- [Legacy qb-clothing protocol](./legacy-protocol.md)

---
title: Configuration
sidebar_position: 2
---

All settings are in `config.lua` (shared, so the client and the server read the same table). Most entries are kora_lib config descriptors. When kora_lib's config module is loaded, `Kora.config.adopt(Config)` resolves them to plain values and makes them editable in kora_lib's config workspace. Settings marked **live** apply without a restart, at the moment noted in the description. Without the config module, the plain default after `or` is used.

## Routing bucket and population

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.bucket.base` | number | `1000000` | Each session runs in bucket `base + source`. |
| `Config.bucket.disablePopulation` | boolean | `true` | Turns ambient peds and vehicles off in the bucket, for the first-character fitting room only. Shop, barber and wardrobe sessions keep the population. Live, read on each fitting-room entry. |
| `Config.bucket.suppressClientPopulation` | boolean | `true` | During character creation, also sets this client's ped and vehicle population budgets to 0 and clears peds and vehicles within 80 m. The budgets go back to 3 when the fitting room closes. Live. |

## Money and services

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
- `prices` is keyed by category (`tops`, `legs`, `shoes`, `body`, `accessories`, see [Sessions](./features/sessions.md#pricing)). Each changed category is charged once. Hair colour and head overlay changes count as `body`.
- `model` (`'male'` or `'female'`) limits the service to one freemode model.
- `tattoos = true` lets the service change tattoos, priced per tattoo from `Config.tattoos`.
- `all = true` (creation) allows every component, prop, the face, skin tone and heritage.

## Character creation

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.starterOutfit.enabled` | boolean | `true` | A new character is reset to the starter outfit before the first spawn, so it never inherits the previous character's clothes. Live. |
| `Config.starterOutfit.male` / `.female` | table | see below | `components` and `props` maps of `{ d, t }` (drawable, texture) keyed by GTA ID. Unlisted components start on drawable 0. Unlisted props are removed. |
| `Config.heritage.creator` | boolean | `true` | Shows the Heritage panel (father and mother for face shape and skin, plus the mixes) in character creation and admin sessions. Live. |

Default starter outfit (both models): torso `3 = { d = 0 }`, legs `4 = { d = 0 }`, shoes `6 = { d = 1 }`, undershirt `8 = { d = 15 }` (none), top `11 = { d = 0 }` (plain t-shirt), no props. The face, skin tone and head overlays start on their defaults, with no tattoos.

## Head overlays

`Config.headOverlays.<key>` exists for `makeup`, `blush`, `lipstick`, `eyebrows`, `facialHair` and `chestHair`. All values are live.

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `<key>.creator` | boolean | `true` (all) | The overlay can be edited in character creation and admin sessions. |
| `<key>.barber` | boolean | `false` for makeup, blush, lipstick. `true` for eyebrows, facialHair, chestHair | The overlay can be edited at barbers and hairdressers, charged at the hair (`body`) price. |
| `<key>.followHairColor` | boolean | `false` | Only for `eyebrows`, `facialHair` and `chestHair`. When `true`, the overlay's palette is hidden and it always uses the primary hair colour. |

## Login colour re-apply

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.loginColourReapply.enabled` | boolean | `true` | After the saved skin is applied on login, the hair colour, highlight and overlay colours are applied again at each delay, because the spawn sequence can reset them. Skipped if a menu opens or the model changes. Live. |
| `Config.loginColourReapply.delays` | number list | `{ 750, 3000 }` | Milliseconds after the first apply. |

## Clothing as items

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.clothingAsItem` | boolean | `false` | When `true`, a paid purchase is given as a `kora_clothing_outfit` item instead of being put on. Requires kora_inventory. Read at resource start for item registration. |
| `Config.clothingItem` | table | see [Items](./items.md) | `name`, `label`, `weight`, `image`, `description` used to register the item. |

## Shops

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.shops` | list | 16 shops | Each entry is one service location. See [Shops and blips](./features/shops.md). |
| `Config.shopZoneDefault` | table | `{ size = vector3(2.0, 1.6, 2.2) }` | Box used for a shop entry without its own `zone`. |
| `Config.shopPeds` | boolean | `false` | Spawns a decorative clerk (`shop.ped`) per shop, client-local, only while the player is near it. |
| `Config.shopPedScopeRadius` | number | `75.0` | Distance at which the decorative clerk is created and removed. |
| `Config.interactDistance` | number | `2.0` | kora_target option range. The server accepts a shop session from inside the zone or within this distance plus 1 m of it. |
| `Config.clothingShopPoints` | boolean | `true` | Clothing shops that have `points = { register, racks }` open from a sphere around each of those points instead of the shop zone. Applies after a restart. |
| `Config.clothingPointRadius` | number | `5.0` | Radius of those spheres (1 to 15). The server allows this radius plus 1 m. Applies after a restart. |
| `Config.interactionMode` | enum | `'textui'` | `'textui'`: kora_lib TextUI `[E] Open <shop>` while inside the shop area. `'target'`: kora_target zone option. Applies after a restart. |
| `Config.showTargetHints` | boolean or nil | `nil` | Forces the kora_target world icon on shop zones on (`true`) or off (`false`). `nil` follows kora_target's own setting. Applies after a restart. |
| `Config.genderLockedSalons` | boolean | `false` | When `true`, barbers serve only male and hairdressers only female freemode models at shop visits. Live, read on each shop visit. |

## Tattoos

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

## Menu (NUI)

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

## Camera

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

## Rotation

See [Camera and rotation](./features/camera.md) for how each mode behaves. All values are live.

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

## Quick toggles

See [Quick toggles](./features/quick-toggles.md).

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

## Closing menus when the player goes down

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.closeWhenDowned.enabled` | boolean | `true` | Cancels open menus on last stand or death. Character creation is never cancelled. Live. |
| `Config.closeWhenDowned.blockOpen` | boolean | `true` | Refuses to open a menu while the player is downed or dead. Live. |
| `Config.closeWhenDowned.checkIntervalMs` | integer | `250` | Poll interval (minimum 50), used only when kora_lib has no cache module. |

## Test-only

`Config.testMode` is not in `config.lua`. The smoke tests set it to expose internal functions. Do not set it on a server.

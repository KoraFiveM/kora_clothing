---
layout: default
title: kora_clothing
---

Illenium-style clothing, appearance and outfit wardrobe for FiveM. A player
trying on clothes at a shop, barber, hairdresser or tattoo parlour is moved
into a **private fitting-room routing bucket** (`Config.bucket.base + source`)
so nobody else can see or interact with them mid-session, with a live-orbit
camera that free-zooms on the mouse wheel and traces its own path so a wall or
counter never lands in shot. Outfits are saved per citizen
(`playerskins` for the current look, `playeroutfits` for up to
`Config.wardrobe.maxOutfits` named presets) created
at startup through
[kora_sql](https://qbcore2.github.io/kora_sql/)'s `Kora.sql.ensureTables`. Purchases are
priced per touched category (clothing/hair/tattoos) and charged through
[kora_core](https://qbcore2.github.io/kora_core/) money, with an optional
"clothing-as-item" mode that boxes a purchase as a physical, reusable
inventory item instead of equipping it directly. `kora_clothing` `provide`s
`qb-clothing` and speaks the real upstream qb-clothing wire protocol (net
events, callback names) directly, so third-party barber/tattoo/uniform
scripts built against it keep working unmodified.

When [kora_hud](https://qbcore2.github.io/kora_hud/) is running, kora_clothing hides it
for the duration of a fitting-room session and restores it on close. Servers
using another HUD need no configuration; the integration is optional.

## Requirements

- [kora_lib](https://qbcore2.github.io/kora_lib/)
- [kora_sql](https://qbcore2.github.io/kora_sql/)
- [kora_core](https://qbcore2.github.io/kora_core/)
- [kora_target](https://qbcore2.github.io/kora_target/) — shops are targeted through kora_target zones

## Installation

`server.cfg`, in this order:
```
set mysql_connection_string "mysql://user:pass@localhost/kora_core?charset=utf8mb4"
ensure kora_sql
ensure kora_lib
ensure kora_core
ensure kora_target
ensure kora_clothing
```
kora_clothing owns its schema (`playerskins`, `playeroutfits`) and applies
its declared tables (`server/schema.lua`) itself via kora_sql's schema handler on first
boot — no manual SQL import needed. `fxmanifest.lua` also declares hard
`dependency` edges on kora_lib/kora_sql/kora_core/kora_target, so FXServer guarantees
correct start order even if `ensure` lines are reshuffled.

## Usage examples

### Open the wardrobe from another resource
```lua
-- client
exports.kora_clothing:OpenWardrobe()
```

### Send a player to a specific shop by config index
```lua
-- client, e.g. from a custom "personal shopper" NPC
exports.kora_clothing:OpenClothingRoom({ shopId = 3 }) -- Config.shops[3] ("Ponsonbys")
```

### Guard against opening the UI twice
```lua
-- client
if not exports.kora_clothing:IsClothingMenuOpen() then
    exports.kora_clothing:OpenWardrobe()
end
```

### Legacy qb-clothing compat, unmodified
```lua
-- client, from a script written against upstream qb-clothing
TriggerEvent('qb-clothing:client:openMenu', 9)      -- open shop index 9 (a Barber)
TriggerEvent('qb-clothing:client:openOutfitMenu')   -- open the wardrobe
```

### Read a citizen's saved appearance (real qb-clothing callback)
```lua
-- client
local model, skin = Kora.callback.trigger('qb-clothing:server:getSkin')
if model then
    print(('saved look uses model %s'):format(model))
end
```

### React once the schema is ready
```lua
-- server
AddEventHandler('kora_clothing:server:persistenceReady', function()
    print('kora_clothing playerskins/playeroutfits tables are ready')
end)
```

## API reference

### Client exports
```lua
exports.kora_clothing:OpenClothingRoom(options)  -- options = { shopId = n } or a bare number
exports.kora_clothing:OpenWardrobe()
exports.kora_clothing:IsClothingMenuOpen()       -- true while the fitting-room NUI is open
exports.kora_clothing:GetPedModels()             -- { male = 'mp_m_freemode_01', female = 'mp_f_freemode_01' }
exports.kora_clothing:ApplyAppearanceToPed(ped, model, skin) -- local preview ped; (true) or (false, err)
```

### Legacy qb-clothing / qb-multicharacter compat events (client)
```lua
TriggerEvent('qb-clothing:client:CreateFirstCharacter')  -- one-time free mandatory fitting
TriggerEvent('qb-clothing:client:openMenu', shopType)     -- numeric shop index or { shopId = n }; no argument = nearest clothing shop
TriggerEvent('qb-clothing:client:openOutfitMenu')         -- open the wardrobe
TriggerEvent('qb-clothing:client:loadOutfit', outfit)     -- { model, skin } applied directly
TriggerEvent('qb-clothing:client:loadOutfit', { outfitData = { bag = { item = 7, texture = 0 } }, outfitName = 'x' })
                                                          -- stock keys overlaid on the current ped; the model is never changed
TriggerEvent('qb-clothing:client:loadPlayerClothing', stockSkin, ped) -- stock skin table onto a freemode ped
TriggerEvent('qb-clothing:client:adjustfacewear', 1)      -- 1 hat, 2 glasses, 3 ears, 4 mask, 5 top (quick toggle)
TriggerEvent('qb-radialmenu:ToggleClothing' | 'qb-radialmenu:ToggleProps' | 'qb-radialmenu:ResetClothing')
                                                          -- mapped onto the /c quick toggles (own ped only)
```

Also emitted: `qb-clothing:client:onMenuClose` when the fitting room closes. Command `/refreshskin` re-applies the saved look.
Exports `reloadSkin`, `IsCreatingCharacter` and `getOutfits` (opens the wardrobe; job room outfits are not supported) exist under `kora_clothing` and `qb-clothing`.
Stock outfit keys: `arms t-shirt torso2 pants shoes bag accessory mask decals vest hair hat glass ear watch bracelet`.

### Legacy server events (caller's own data only, rate limited)
```lua
Kora.callback.trigger('qb-clothing:server:getOutfits')   -- own outfits: { id, outfitId, outfitname, model, skin } (skin in Kora format)
TriggerServerEvent('qb-clothing:server:removeOutfit', outfitName, outfitId) -- outfitId is the numeric id from getOutfits
TriggerServerEvent('qb-clothes:loadPlayerSkin')          -- replies to the caller with qb-clothes:loadSkin
```
`qb-clothing:saveSkin` and `qb-clothes:saveOutfit` are intentionally not provided.

### Callbacks (`Kora.callback`, real qb-clothing/qb-multicharacter names)
```lua
Kora.callback.trigger('qb-clothing:server:getSkin')                    -- -> model, skin
Kora.callback.trigger('qb-multicharacter:server:getSkin', citizenid)   -- -> model, skin (char-select preview)
Kora.callback.trigger('kora_clothing:server:getOutfitSkin', outfitId)     -- -> model, skin (session-scoped)
```

The multicharacter preview callback is pre-login safe: kora_core verifies that
the requested active character belongs to the requesting license before any
appearance is returned. Foreign and soft-deleted citizen IDs are rejected;
successful results are sanitized, rate-limited, and cached for that source's
selection session.

### The fitting-room camera

The preview camera orbits the ped and lerps between the five body-region zoom
presets in `Config.camera.zones` (full body / face / torso / legs / shoes).

**Starting view.** The camera opens in front of the ped, face-on, framing the
whole body. `Config.camera.initialView` (`'front'` default, `'current'` for the
old angle-0 start, which is often side-on) and `Config.camera.initialPreset`
(a key of `Config.camera.zones`, default `'full'`) control this; both are read
each time a menu opens.

**Head and feet framing.** The face and shoes presets are centred on the
ped's `SKEL_Head` and foot bones (`track` / `trackOffset` on the zone), so they
fit any ped model or height, and the camera is never lower than
`Config.camera.minHeightAboveGround` (default `0.15` m, `0` disables) above the
floor, so the shoes view cannot go under the map. `Config.camera.frameToBones =
false` returns to the fixed spine offsets.

**Holding still.** A frozen ped still plays its idle animation (breathing,
shifting weight, looking around). With `Config.camera.holdStill` (default
`true`) those idle fidgets are paused while a menu is open, and the camera is
aimed from one measurement of where the ped stands (taken when the menu opens,
and again if the model changes) instead of following its spine and head bones
every frame. Following them made the whole view sway, so the ped looked like it
was moving in place, most of all while rotating. The ped is also given a
stand-still task and its head IK is switched off for the menu: the player's
normal on-foot behaviour turns the head and upper body to look at the camera, so
as the orbit swung round the ped kept turning towards it. Both are handed back
when the menu closes (a ped that went down meanwhile keeps the death handling's
animation). Only the camera orbits; the ped's heading never changes (except in `'capture'`
rotate mode, which turns the ped and keeps the camera fixed; see **Rotating**). `false`
keeps the old per-frame tracking and leaves the ped's tasks alone.

**Categories.** Choosing a category does not move the camera by default, so the
player's own rotation and zoom survive tab changes and the preset buttons stay
the way to reframe. Set `Config.camera.resetOnCategoryChange = true` to jump to
`Config.camera.categoryZones` on every category change.

**Rotating.** Hold the left mouse button (or the right, unless
`Config.rotateRightButton = false`) over the character and drag. `Config.rotateMode` picks how the
drag survives the cursor reaching the screen edge (read each time a menu opens).
`Config.rotateModeByService` overrides it per menu, keyed by the session's service
(`clothing`, `barber`, `hairdresser`, `tattoo`, `creation`); an unset entry follows
`Config.rotateMode`. Every entry is unset by default, so barbers and hairdressers,
like character creation, clothing shops and tattoo studios, use `Config.rotateMode`
(`'capture'`: the cursor is hidden for the drag and held inside the game window, so it
can never reach a second monitor). Set a menu to `'plain'` to leave the cursor alone
there; it is then hidden but free to leave a windowed game.

In every mode the drag turns the character, not the camera
(`Config.rotateTurnsPed`, default `true`): the camera stays where the menu framed
it, clear of walls, so rotating can never swing it through a wall or the floor of
a small shop. The character faces its original direction again when the menu
closes. `false` orbits the camera around the character instead, and nothing then
stops the camera passing through a wall behind the character.

The cursor is hidden while a rotate drag is held, in every mode
(`Config.rotateHideCursor`, default `true`), and on release it reappears where
the drag started, never where the hidden cursor drifted to or at the screen
centre. The modes Lua drives (`'capture'`, `'controls'`) always do this; the
others do it with `Config.rotateRestoreCursor` (default `true`), and the NUI keeps
the cursor hidden until Lua has moved it back (at most 250 ms).
`Config.rotateSensitivity` (default `1.0`) scales the degrees turned per pixel in
the plain, capture, pointer and recenter modes:

- `'plain'` — a normal press/move/release drag. The NUI turns the
  character from the mouse movement it sees (`movementX`), one
  `kora_clothing:nui:rotate` message per animation frame, and the cursor is never
  touched: no Lua thread, no `SetCursorLocation`, no NUI focus change. A full-screen
  overlay owns the cursor for the whole drag: hidden by default
  (`Config.rotateHideCursor`), or with that off the cursor set by
  `Config.rotateDragCursor` (`'grabbing'` or `'hidden'`). The cursor stops at the screen edge, so a very long
  drag the same way needs a second click, and nothing keeps it inside a windowed game
  (it can reach a second monitor), which is why `'capture'` is the default.
- Every mode below moves the cursor itself to keep rotating at the edge. A visible
  cursor that is moved flickers (arrow / hand), so in these modes the cursor is
  always hidden for the drag, whatever `Config.rotateHideCursor` and
  `Config.rotateDragCursor` say.
- `'capture'` — the NUI hands the drag to `client/rotate.lua` but keeps
  its focus and cursor, so it always sees the button come up. Every frame Lua
  reads the cursor (`GetNuiCursorPosition`) and turns the character by how
  far it moved (`Config.rotateTurnsPed`, above). Once it is more than 8% of the screen from the centre pulls it
  back (`SetCursorLocation(0.5, 0.5)`), ignoring the jump the pull causes. The
  pull happens in the same frame rather than after a round trip from the NUI,
  so even a fast flick cannot carry the cursor to a screen edge or out of the
  window onto another monitor. The cursor is hidden for the drag and, on
  release, put back where the drag began; NUI focus never changes, so nothing blinks. Nothing runs
  until the button goes down: the per-frame thread exists only for the held drag,
  which ends on release, a window blur, Escape, menu close or
  `Config.rotateControlsMaxSeconds`. If the cursor natives are missing Lua
  declines and the NUI recentres near the edge instead.
- `'pointer'` — the browser Pointer Lock request on mouse down
  (`Config.rotatePointerLock`, `false` = plain drag), turning by `movementX`.
  FiveM's NUI refuses the lock, so in practice the drag falls back to
  `'recenter'`, which a fast flick can outrun.
- `'controls'` — the NUI hands the drag to Lua. While the button is
  held the cursor is hidden (`SetNuiFocus(true, false)`), the mouse reaches the
  game as `INPUT_LOOK_LR`, and `client/rotate.lua` turns the camera from that
  each frame. The drag ends on button release, Backspace/Esc, after
  `Config.rotateControlsMaxSeconds` (30s, a hard stop), or when the menu
  closes; NUI focus and the cursor position are then restored.
  `Config.rotateControlsSensitivity` (default `8.0`) sets degrees per unit of
  movement. If the game never reports the held button, the drag lasts while
  the mouse moves and ends `Config.rotateControlsIdleSeconds` (0.4s) after it
  stops. If Lua declines (`kora_clothing:nui:rotateStart` replies
  `active = false`) the NUI falls back to a plain drag.
- `'recenter'` — the cursor drag stays in the NUI; near a screen edge the NUI
  asks Lua (`kora_clothing:nui:recenter`, throttled) to `SetCursorLocation(0.5, 0.5)`
  and ignores the resulting jump.

Every mode ends the drag on mouse release, window blur, Escape and menu close
(`Config.rotateDragGuard`).

**Scrolling the menu.** The menu columns are click-through (only their panels
take input), and FiveM's NUI does not scroll a column from a wheel over one of
its panels, which left the arrow keys as the only way to move the right-hand
menu. The wheel is therefore handled once, at the window (`web/src/lib/railWheel.ts`):
anywhere over a column that can scroll, it scrolls that column, gliding over a
few frames, and never zooms the camera. The arrow keys still work. The grey
scrollbar is hidden unless `Config.ui.showScrollbar = true`.

**Free zoom.** The mouse wheel zooms continuously, as an offset on top of
whichever preset is selected — `Config.camera.zoom` sets the step per wheel
notch and the radius bounds it is clamped to. The presets remain jump-to
shortcuts: picking one discards the accumulated wheel offset and returns to its
authored framing. The NUI sends wheel *notches* rather than pixel deltas
(`kora_clothing:nui:zoom`), because `deltaY` magnitude is not comparable between a
mouse, a trackpad and CEF's line/page delta modes.

**No obstructions.** Before the camera settles at a framing, a capsule shape
test is run from the point it is aimed at to the point it would sit. If
anything — world geometry, a prop, a parked car, foliage — is in the way, the
camera fans around the ped at the same distance (±28°, ±55°, ±82°, then behind,
the wider angles also lifted) and takes the first clear angle, so the authored
framing is preserved. Only if no angle is clear at all does it pull in to just
short of the obstruction, and never nearer than `Config.camera.zoom.min`. This
is re-resolved whenever the zone or the zoom changes, on its own coalescing
thread — the shape test has to yield for its result, so running it on the frame
the camera is positioned would stall that frame.

Barber and hairdresser are `service` values inside this same session, not
separate UIs, so both get free zoom and the unobstructed camera with no
per-service configuration. Every grooming target accepts either freemode
gender: the server routes the session to the matching barber or hairdresser
policy before validating and opening it. With `Config.genderLockedSalons`
on, shop visits are instead gender-locked (barber male, hairdresser female)
and the wrong gender gets a notice; admin sessions still follow the model.

### Hair colour

Barber, hairdresser, character-creation and admin sessions can set a **primary
and a secondary (highlight) hair colour**, persisted with the rest of the
appearance as `hairColor` / `hairHighlight`.

These are **palette indices, not RGB.** GTA's `SetPedHairColor(ped, colorId,
highlightColorId)` takes two entries from the model's own fixed hair palette
(~64 on the freemode models) and there is no native that accepts a colour
value, so a free RGB picker would have nothing to send. Instead the client
reads the real colour behind every index with `GetPedHairRgbColor`, sends that
palette once with the session payload, and the NUI renders it as two swatch
grids — the look of a colour picker, with only legal indices ever crossing the
wire. Indices are clamped server-side against `Shared.maxHairColorIndex` and
again client-side against the live `GetNumHairColors()` before the native call.

The controls appear only while the hair component is selected; a clothing shop
is sent no palette at all, matching the server-side merge, which gates hair
colour on the same whitelist as component `2` (so a clothing shop cannot apply
a recolour a barber charges for). A recolour-only visit is priced as a change
to the hair component's category.

### Session net events
```lua
-- client -> server (kora_lib's tokenised Kora.events gateway, not a raw
-- RegisterNetEvent -- confirmSession moves real money and requestSession
-- gates an admin-only free fitting, so these go through the per-session
-- token instead of a guessable static event name; see kora_lib's
-- local/events/docs.md)
Kora.events.trigger('kora_clothing:server:requestSession', mode, extra)  -- mode: 'firstCharacter'|'shop'|'wardrobe'
Kora.events.trigger('kora_clothing:server:confirmSession', { model, skin, saveName })
Kora.events.trigger('kora_clothing:server:cancelSession')
Kora.events.trigger('kora_clothing:server:deleteOutfit', outfitId)

-- server -> client
TriggerClientEvent('kora_clothing:client:openSession', src, payload)
TriggerClientEvent('kora_clothing:client:outfitsUpdated', src, outfits)
TriggerClientEvent('kora_clothing:client:sessionError', src, message)
TriggerClientEvent('kora_clothing:client:closeSession', src, result)
TriggerClientEvent('kora_clothing:client:wearItem', src, model, skin)   -- clothingAsItem use handler
```
A session is entered by `requestSession` (shop sessions require standing
inside the shop's target zone or within `Config.interactDistance` plus one
metre of it, the same reach the kora_target option has; anyone further away
is told to move closer), finalised by
`confirmSession` (server re-diffs, prices and persists — never trusts the
client's price), and torn down by `cancelSession` or `closeSession`. Shop
sessions are also reachable via kora_target zones placed on each configured
shop, and `kora_clothing:client:openNearestShop(service)` opens the closest
shop by proximity for the given service (`'clothing'` by default, or
`'barber'`/`'tattoo'`) — used by kora_admin's self-service clothing/barber/tattoo
entries. `kora_clothing:client:openAdminSession` opens a free, unrestricted
clothing+hair+tattoo session (the same `creation` service policy used for
first-character fittings); the server re-checks `admin` permission before
granting it regardless of what kora_admin's menu shows client-side.

kora_admin can also open a single free `clothing`, `barber`/`hairdresser`, or
`tattoo` service for another player through kora_clothing's server-only
`OpenAdminSession(targetSrc, service)` integration. The export accepts calls
only from the `kora_admin` resource, creates a ten-second one-use authorization,
and the target consumes it through the normal token-authenticated session
request. A female freemode model selected through the barber action is routed
to the hairdresser policy automatically.

### First-character fitting

`qb-multicharacter:client:closeNUIdefault` (fired by kora_core only on successful
character creation) *arms* the mandatory first fitting; it does not open it.
The open waits for [kora_multichar](https://qbcore2.github.io/kora_multichar/)'s
`kora_multichar:client:spawnComplete` event, which lands once the ped has been
placed, resurrected, revealed and the fade-in has finished — so the fitting
room can never appear over the spawn carousel or mid-teleport. On a server
running third-party `qb-multicharacter`, where no such event exists, the old
behaviour applies: wait for the ped to be active and alive, then open.

## Config highlights (`config.lua`)

- `Config.bucket.base` (1,000,000) — fitting-room routing bucket offset, `base + source`
- `Config.bucket.disablePopulation` (true) — switches ambient peds/vehicles off in the first-character fitting room bucket only; shops, barbers and wardrobes keep the world population
- `Config.shop.currency` — account charged for purchases (default `cash`)
- `Config.genderLockedSalons` (false, live in-game option) — when true, barbers serve only male and hairdressers only female freemode models at shops (no menu swap); admin sessions, creation and other services are unaffected
- `Config.services` — per-service (`clothing`/`barber`/`hairdresser`/`tattoo`/`creation`) component/prop whitelists, prices and gender restrictions
- `Config.wardrobe.maxOutfits` (20) — saved-outfit cap per citizen
- `Config.clothingAsItem` (default `false`) — when `true`, a purchase/save is boxed as a `kora_clothing_outfit` inventory item (via [kora_inventory](https://qbcore2.github.io/kora_inventory/)) instead of equipping directly
- `Config.shops` — per-shop service, coordinates, target zone geometry (`zone = { size, rotation }`, or `{ points, minZ, maxZ }` for an irregular shape), blip and optional clerk model
- `Config.shopPeds` (default `false`) — spawn a decorative clerk per shop only while the local player is near it. The interaction target is the storefront zone either way; a ped-bound target dies with the ped (unstreamed model, shoved out of place, deleted by another resource) and leaves the shop silently unopenable, so the ped is set dressing only
- `Config.shopPedScopeRadius` (75.0m) — the radius that creates a decorative clerk for the local player; independent of the interaction range
- `Config.shopZoneDefault` — fallback box for a shop entry added without its own `zone`
- `Config.tattoos` — the base-game overlay catalogue with per-tattoo pricing
- `Config.tattoo.allowStacking` (default `true`) — a copy button on applied tattoos adds another instance of the same tattoo so it renders darker; the skin keeps the tattoo id repeated once per instance. `false` allows one instance per tattoo (extras are dropped server-side)
- `Config.tattoo.maxStack` (default `3`, 1–10) — most instances of one tattoo; enforced server-side
- `Config.tattoo.stackPriceMultiplier` (default `1.0`) — each added instance is priced like a new tattoo; instances beyond the first of a tattoo are scaled by this (`0.5` half price, `0` free). Existing instances are never charged again
- `Config.tattoo.undress.enabled` (default `true`) — clothing buttons in the tattoo studio (see [Tattoo studio](#tattoo-studio)); `false` returns to the fixed `Config.tattooStrip` with no buttons
- `Config.tattoo.undress.autoUndressOnOpen` (default `{ 'top', 'legs', 'headwear' }`) — part ids bared when the studio opens; `{}` opens fully dressed
- `Config.tattoo.undress.parts` — one button per part: the bare component drawables per freemode model (`male` / `female`) and the prop slots cleared
- `Config.tattoo.peds.enabled` (default `true`) — a tattoo artist ped in each tattoo shop with a "Get tattooed" target, replacing the shop zone prompt while it stands there; `alpha` (0), `scopeRadius` (40.0m), `model` (`u_m_y_tattoo_01`) and `scenario` (`WORLD_HUMAN_STAND_IMPATIENT`) tune it
- `Config.ui.clothingToggles` — preview clothing switches stacked on the left of the menu, under My Outfits (see [Preview clothing switches](#preview-clothing-switches)):
  - `enabled` (default `true`) — master switch
  - `services` (default `{ 'barber', 'hairdresser' }`) — menus that show them (`barber`, `hairdresser`, `clothing`, `creation`)
  - `items.hat` / `items.shirt` / `items.pants` / `items.shoes` (each default `true`) — which switches are shown
  - It replaces `Config.ui.barberTopToggle`; setting that to `false` still hides the Shirt switch
- `Config.headOverlays.<facialHair|eyebrows|chestHair>.followHairColor` (default `false`) — `true` hides that overlay's color palette and always uses the primary hair color. This replaces the old "Match hair colour" button, which is gone from the menu
- `Config.heritage.creator` (default `true`) — a Heritage panel with the Face item in character creation (and admin sessions): a father and a mother for the face shape and for the skin (`Auto` follows the Face style and the Skin tone, which is what characters saved before heritage existed use) and a mix for each, 0% all father to 100% all mother. It is saved in the head table as `shapeFirst`/`shapeSecond`/`skinFirst`/`skinSecond` (-1 to 45) and `shapeMix`/`skinMix` (0 to 1). `false` hides it and keeps whatever a character already has. Creation-only, like skin tone
- `Config.headOverlays.<makeup|blush|lipstick>.creator` (default `true`) and `.barber` (default `false`) — make-up, blush and lipstick sections (head overlays 4, 5 and 8) under the Hair item, each with a style, an opacity and a colour from the game's make-up palette (colour type 2; they never follow the hair colour). `.barber = true` offers them at barbers and hairdressers at the hair price
- `Config.interactDistance` (2.0) — kora_target zone range; the server accepts a shop session from inside the zone or within this distance plus one metre of it
- `Config.camera.zones` — per-zone (`full`/`face`/`torso`/`legs`/`shoes`) framing presets for the fitting-room camera
- `Config.camera.holdStill` (default `true`) — pause idle fidgets, stop the ped turning to look at the camera, and keep the camera fixed on where the ped stands while a menu is open (see [The fitting-room camera](#the-fitting-room-camera))
- `Config.ui.showScrollbar` (default `false`) — draw the scrollbar on the menu columns; they scroll with the wheel and arrow keys either way
- `Config.rotateMode` (default `'capture'`) — how drag-to-rotate keeps the cursor from the screen edge; see [The fitting-room camera](#the-fitting-room-camera)
- `Config.rotateModeByService` (all of `clothing`, `barber`, `hairdresser`, `tattoo` and `creation` unset by default, so every menu, barber and hairdresser included, uses `Config.rotateMode`, `'capture'`) — per-menu `rotateMode` override; unset entries follow `Config.rotateMode`
- `Config.rotateTurnsPed` (default `true`) — in every rotate mode the drag turns the character and the camera stays where the menu framed it, so it cannot clip through walls or the floor; the opening heading is restored on close. `false` orbits the camera instead (replaces the capture-only `Config.captureRotatesPed`)
- `Config.rotateHideCursor` (default `true`) — hide the cursor while a rotate drag is held, in every mode; release shows it again
- `Config.rotateHideMethod` (`'blank'` default, or `'none'`) — how the cursor is hidden for the drag. `'blank'` swaps it for a transparent image cursor (falling back to CSS `cursor: none`), because FiveM's browser does not always act on `cursor: none` alone and the arrow stayed visible; `'none'` uses `cursor: none` only. Only used while `Config.rotateHideCursor` is on
- `Config.rotateRestoreCursor` (default `true`) — on release the hidden cursor reappears where the drag started (`'capture'` / `'controls'` always do this)
- `Config.starterOutfit` — the outfit a new character starts in, so it never inherits the previous character's clothes: `enabled` (default `true`), and per freemode model (`male` / `female`) `components` and `props` maps of `{ d, t }`. Unlisted components start on drawable 0, unlisted props are removed, and the face, skin tone, beard and other head overlays start on their defaults with no tattoos. Defaults: plain t-shirt (11/0, arms 3/0), no undershirt (8/15), legs 4/0, shoes 6/1
- `Config.rotateRightButton` (default `true`) — the right mouse button rotates as well as the left
- `Config.camera.zoom` — `{ min, max, step }` bounds for free mouse-wheel zoom (metres of camera radius; `step` is per wheel notch)
- `Config.camera.orbitDegPerSec` / `Config.camera.transitionMs` — orbit and zoom-transition speeds
- `Config.camera.transitionMs` (default `500`) — time a change of view takes to settle; position, look-at height and fov ease together, never snap.
- `Config.camera.occlusionMaxSwing` (default `55`°) — furthest the camera may swing round an obstruction; keeps it in front of the character (`180` = old side/rear behaviour).
- `Config.rotateDragCursor` (`'grabbing'` default, or `'hidden'`) — cursor held for the whole rotate drag in `'plain'` mode when `Config.rotateHideCursor` is off; the modes that move the cursor always hide it.
- `Config.bucket.suppressClientPopulation` (default `true`) — while a new character is created, also zero this client's ped/vehicle population budgets and clear nearby ones (restored on close). The personal routing bucket + `Config.bucket.disablePopulation` already isolate the player server-side.

## Menu text and languages

The hair, facial hair, eyebrows and chest hair boxes (and the clothing switches) take their wording from `locales/en.json`, which the client sends with each session. English reads "Color". To translate, add `locales/<language>.json` with the same `ui` keys; kora_lib picks it from the `kora_locale` convar and falls back to English per key. Keys not listed in the locale file keep the English default.

## Preview clothing switches

Barbers and hairdressers show four switches on the left of the menu, under My Outfits: Hat, Shirt, Pants and Shoes. Each takes that item off the ped and puts it back, so chest hair or a new cut can be seen. On means worn. Barbers and hairdressers take the hat off as they open, so the Hat switch starts off there.

They are a preview only. The change lives on the local ped and is never sent to the server, saved or charged. The real clothing comes back when the switch is turned on again and whenever the menu closes: confirm, cancel, Esc, going down or a resource stop. The confirm snapshot always carries the real items. Wearing a saved outfit keeps each switch where it was, and turning one back on then puts on the outfit's item.

Shirt (top, undershirt and arms/gloves), Pants and Shoes use the matching part of `Config.tattoo.undress.parts` (`top`, `legs`, `shoes`) for the bare look, with the stock freemode values if that list has no such part. Hat clears the hat prop only. Configure them with `Config.ui.clothingToggles` (see the config list above).

## Closing menus when the player goes down

If a player enters last stand / bleed-out or dies while a clothing, barber, surgeon, tattoo or outfit menu is open, the menu runs the normal Cancel (preview reverted, NUI closed, camera, focus and HUD restored). It reacts to kora_ambulance's `emsDown` player state bag (last stand keeps the ped alive, so a plain "is dead" check misses it) and to the kora_lib cache's `isDead` change, so nothing polls while a menu is open. The one-time first-character creation is never cancelled.

| `Config.closeWhenDowned` option | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Close open menus on last stand / death. Off keeps the old behaviour (only a ped death closes the tattoo studio and menus with clothing switches). |
| `blockOpen` | `true` | Also refuse to open a menu while downed or dead; the player is told why. |
| `checkIntervalMs` | `250` | Only with a kora_lib that has no cache module: poll interval while a menu is open (minimum 50). |

A menu that is still recorded as open while no NUI has focus (it lost its screen) no longer blocks the next shop visit: the leftover session is cancelled and the new menu opens.

## Quick clothing toggles (`/c <part>`)

Take one item off, or put it back, without opening the clothing menu:
`/c vest`, `/c shirt`, `/c pants`, `/c shoes`, `/c hat`, `/c mask`, `/c visor`,
`/c glasses`, plus `bag`, `chain`, `ears`, `watch` and `bracelet`. Aliases work
too (`top` = shirt, `helmet` = hat, `legs` = pants, ...). `/c` on its own, or
with an unknown part, shows the usage. `/c reset` (or `/c all`) puts everything
back.

- Each use **toggles**: the first removes the item, the second restores exactly
  what was worn (drawable, texture, palette). `shirt` also removes the
  undershirt and arms so the torso looks right.
- **Temporary**: nothing is sent to the server or saved; the saved outfit is the
  "put back" state. If the player changes an item meanwhile (clothing menu,
  outfit, another script) the remembered value is dropped, never restored over
  their change. The command is blocked while a fitting-room menu is open, and the menu starts from the saved outfit.
- `visor` swaps a hat/helmet with its visor-up/visor-down drawable using
  `Config.quickToggle.visor` (`{ male = { [hatDrawable] = otherDrawable } }`).
  GTA cannot detect visor variants, so it ships empty and the player sees "no
  visor to flip" until you list the helmets of your pack.
- Gloves are not a separate argument: gloves are part of the arms (component 3),
  which `shirt` already bares.
- Client side only (`client/quicktoggle.lua`), chat suggestion included.

| `Config.quickToggle` option | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Turns the whole feature off (no command, no suggestion). |
| `command` | `'c'` | Command name; change it if another resource uses `/c`. Read at start. |
| `chatSuggestion` | `true` | Register the chat suggestion listing the parts. |
| `cooldownMs` | `1500` | Minimum time between uses; `0` disables. |
| `allowDead` / `allowCuffed` | `false` / `false` | Work while dead or handcuffed (cuffed needs kora_police). |
| `allowInVehicle` | `true` | Work while seated in a vehicle. |
| `animations` | `true` | Short clothing animation per part. |
| `animationsInVehicle` | `false` | Play the animation in a vehicle too. |
| `resetWords` | `{ 'reset', 'all' }` | Arguments that put everything back. |
| `visor` | empty | Helmet visor drawable pairs per gender. |
| `parts` | see `config.lua` | Per part: `id`, `aliases`, `label`, per-gender `male`/`female` "nothing" components, `props` slots, `visor`, `animDict`/`animClip`/`animMs`. |

## Tattoo studio

### Clothing buttons

The studio previews tattoos on bare skin, so the torso, arms and legs are visible. A small bar above the bottom bar lets the player take clothing off and put it back while they look: Top (jacket, undershirt, arms/gloves), Legs, Shoes, Hat/mask/glasses, and Undress all / Dress.

- **Preview only.** The change is made on the local ped. It is never sent to the server, never saved into the outfit and never charged: the confirm request carries the clothing the player walked in wearing.
- **Restored exactly.** Whatever the player wore comes back on confirm, cancel, Esc, death (the session is cancelled) and when the resource stops.
- **Which parts start off.** `Config.tattoo.undress.autoUndressOnOpen` (default top, legs and head cover, which is what the studio always did). Shoes stay on unless added.
- **Bare drawables.** `Config.tattoo.undress.parts` holds a `male` and a `female` list of `{ id, d, t }` (GTA component id, bare drawable, texture) and a `props` list of cleared prop slots (0 hat, 1 glasses, 2 ear piece). The defaults are the stock freemode drawables; adjust them if a clothing pack changes what looks bare. A drawable the ped does not have is skipped.
- **Off.** `Config.tattoo.undress.enabled = false` shows no buttons and keeps the fixed `Config.tattooStrip`.

The camera zone buttons work the same with parts bared.

### Tattoo artist ped

Every shop with `service = 'tattoo'` gets a client-side, frozen, invincible artist (`Config.tattoo.peds.enabled`, on by default like the shop clerks in kora_inventory). Each artist is a kora_lib zone of `scopeRadius` metres: the ped is created when the player walks into it and deleted when they leave, so nothing polls. Targeting the artist ("Get tattooed") opens the studio. While the artist stands there the shop's own zone is taken down, so there is no second "Open Tattoo Artist" option and no zone sprite next to the artist; the zone comes back whenever there is no artist (player away, option off, model missing). While the studio is open the artist is set to `Config.tattoo.peds.alpha` (0 = invisible) for that player only, and is reset on close. Artists are also deleted when the option is turned off and when the resource stops.

Turn it off on a map or MLO that already has its own tattoo artist; the shop zone is then used as before. While it is on, the decorative `Config.shopPeds` clerk is not also spawned at tattoo shops. Changes to `enabled`, `scopeRadius`, `model` and `scenario` apply live. With `Config.interactionMode = 'textui'` the artist is decoration and the shop opens from the prompt.

The artist plays `scenario` (default `WORLD_HUMAN_STAND_IMPATIENT`; unset or `''` for a plain idle). Avoid scenarios with a hand prop such as a clipboard or phone: fading only reaches the ped, so the prop would stay in view in the studio.

The default shops already name `u_m_y_tattoo_01` and the artist stands at the shop's `coords`, which are a standing player's position (as `/coords` or `GetEntityCoords` report, about 1.0 above the floor); the ped is placed 1.0 lower, on the floor. A shop can override this in `Config.shops` (same height convention):

```lua
tattooPed = { model = 'u_m_y_tattoo_01', coords = vector4(x, y, z, heading), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
-- or tattooPed = false for no artist at this shop
```

Keep the artist within a metre or two of the shop's zone: the server only opens a session for players near it.

## Pause-map blips

Every shop blip uses a canonical named category: `Clothing`, `Tattoo`, or
`Grooming`. Barber and hairdresser locations deliberately share `Grooming`
instead of splitting one service across two legend headings. Clothing shops
also pass their storefront name (`Suburban`, `Ponsonbys`, or `Binco`), so kora_lib
renders labels such as `Clothing: Ponsonbys`; generic Tattoo and Grooming
markers render only the category. The shop's own `label` remains the kora_target
interaction prompt.

## Related resources

Part of the [qbcore2](https://github.com/qbcore2) resource set:

- [kora_lib](https://qbcore2.github.io/kora_lib/) — shared helper library
- [kora_sql](https://qbcore2.github.io/kora_sql/) — database driver
- [kora_core](https://qbcore2.github.io/kora_core/) — framework core
- [kora_inventory](https://qbcore2.github.io/kora_inventory/) — headless inventory
- [kora_target](https://qbcore2.github.io/kora_target/) — targeting/interaction
- [kora_admin](https://qbcore2.github.io/kora_admin/) — admin menu
- [full resource list ↗](https://github.com/orgs/qbcore2/repositories)

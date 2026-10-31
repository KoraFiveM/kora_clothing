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
`Config.wardrobe.maxOutfits` named presets) via
[qbsql](https://qbcore2.github.io/kora_sql/)'s migration runner. Purchases are
priced per touched category (clothing/hair/tattoos) and charged through
[qbcore](https://qbcore2.github.io/kora_core/) money, with an optional
"clothing-as-item" mode that boxes a purchase as a physical, reusable
inventory item instead of equipping it directly. `kora_clothing` `provide`s
`qb-clothing` and speaks the real upstream qb-clothing wire protocol (net
events, callback names) directly, so third-party barber/tattoo/uniform
scripts built against it keep working unmodified.

When [qbhud](https://qbcore2.github.io/kora_hud/) is running, kora_clothing hides it
for the duration of a fitting-room session and restores it on close. Servers
using another HUD need no configuration; the integration is optional.

## Requirements

- [kora_lib](https://qbcore2.github.io/kora_lib/)
- [qbsql](https://qbcore2.github.io/kora_sql/)
- [qbcore](https://qbcore2.github.io/kora_core/)
- [qbtarget](https://qbcore2.github.io/kora_target/) — shops are targeted through kora_target zones

## Installation

`server.cfg`, in this order:
```
set mysql_connection_string "mysql://user:pass@localhost/qbcore?charset=utf8mb4"
ensure kora_sql
ensure kora_lib
ensure kora_core
ensure kora_target
ensure kora_clothing
```
kora_clothing owns its schema (`playerskins`, `playeroutfits`) and applies
`sql/001_playerskins_outfits.sql` itself via kora_sql's migration runner on first
boot — no manual SQL import needed. `fxmanifest.lua` also declares hard
`dependency` edges on kora_lib/kora_sql/kora_core/qbtarget, so FXServer guarantees
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
local model, skin = QB.callback.trigger('qb-clothing:server:getSkin')
if model then
    print(('saved look uses model %s'):format(model))
end
```

### React once the schema is ready
```lua
-- server
AddEventHandler('qbclothing:server:persistenceReady', function()
    print('qbclothing playerskins/playeroutfits tables are ready')
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
TriggerEvent('qb-clothing:client:openMenu', shopType)     -- numeric shop index or { shopId = n }
TriggerEvent('qb-clothing:client:openOutfitMenu')         -- open the wardrobe
TriggerEvent('qb-clothing:client:loadOutfit', outfit)     -- { model, skin } applied directly
```

### Callbacks (`QB.callback`, real qb-clothing/qb-multicharacter names)
```lua
QB.callback.trigger('qb-clothing:server:getSkin')                    -- -> model, skin
QB.callback.trigger('qb-multicharacter:server:getSkin', citizenid)   -- -> model, skin (char-select preview)
QB.callback.trigger('qbclothing:server:getOutfitSkin', outfitId)     -- -> model, skin (session-scoped)
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

**Categories.** Choosing a category does not move the camera by default, so the
player's own rotation and zoom survive tab changes and the preset buttons stay
the way to reframe. Set `Config.camera.resetOnCategoryChange = true` to jump to
`Config.camera.categoryZones` on every category change.

**Free zoom.** The mouse wheel zooms continuously, as an offset on top of
whichever preset is selected — `Config.camera.zoom` sets the step per wheel
notch and the radius bounds it is clamped to. The presets remain jump-to
shortcuts: picking one discards the accumulated wheel offset and returns to its
authored framing. The NUI sends wheel *notches* rather than pixel deltas
(`qbclothing:nui:zoom`), because `deltaY` magnitude is not comparable between a
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
policy before validating and opening it.

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
-- client -> server (kora_lib's tokenised QB.events gateway, not a raw
-- RegisterNetEvent -- confirmSession moves real money and requestSession
-- gates an admin-only free fitting, so these go through the per-session
-- token instead of a guessable static event name; see kora_lib's
-- local/events/docs.md)
QB.events.trigger('qbclothing:server:requestSession', mode, extra)  -- mode: 'firstCharacter'|'shop'|'wardrobe'
QB.events.trigger('qbclothing:server:confirmSession', { model, skin, saveName })
QB.events.trigger('qbclothing:server:cancelSession')
QB.events.trigger('qbclothing:server:deleteOutfit', outfitId)

-- server -> client
TriggerClientEvent('qbclothing:client:openSession', src, payload)
TriggerClientEvent('qbclothing:client:outfitsUpdated', src, outfits)
TriggerClientEvent('qbclothing:client:sessionError', src, message)
TriggerClientEvent('qbclothing:client:closeSession', src, result)
TriggerClientEvent('qbclothing:client:wearItem', src, model, skin)   -- clothingAsItem use handler
```
A session is entered by `requestSession` (shop sessions require standing
within `Config.interactDistance` of the shop's `coords`), finalised by
`confirmSession` (server re-diffs, prices and persists — never trusts the
client's price), and torn down by `cancelSession` or `closeSession`. Shop
sessions are also reachable via kora_target zones placed on each configured
shop, and `qbclothing:client:openNearestShop(service)` opens the closest
shop by proximity for the given service (`'clothing'` by default, or
`'barber'`/`'tattoo'`) — used by kora_admin's self-service clothing/barber/tattoo
entries. `qbclothing:client:openAdminSession` opens a free, unrestricted
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
The open waits for [qbmultichar](https://qbcore2.github.io/kora_multichar/)'s
`qbmultichar:client:spawnComplete` event, which lands once the ped has been
placed, resurrected, revealed and the fade-in has finished — so the fitting
room can never appear over the spawn carousel or mid-teleport. On a server
running third-party `qb-multicharacter`, where no such event exists, the old
behaviour applies: wait for the ped to be active and alive, then open.

## Config highlights (`config.lua`)

- `Config.bucket.base` (1,000,000) — fitting-room routing bucket offset, `base + source`
- `Config.shop.currency` — account charged for purchases (default `cash`)
- `Config.services` — per-service (`clothing`/`barber`/`hairdresser`/`tattoo`/`creation`) component/prop whitelists, prices and gender restrictions
- `Config.wardrobe.maxOutfits` (20) — saved-outfit cap per citizen
- `Config.clothingAsItem` (default `false`) — when `true`, a purchase/save is boxed as a `qbclothing_outfit` inventory item (via [qbinventory](https://qbcore2.github.io/kora_inventory/)) instead of equipping directly
- `Config.shops` — per-shop service, coordinates, target zone geometry (`zone = { size, rotation }`, or `{ points, minZ, maxZ }` for an irregular shape), blip and optional clerk model
- `Config.shopPeds` (default `false`) — spawn a decorative clerk per shop only while the local player is near it. The interaction target is the storefront zone either way; a ped-bound target dies with the ped (unstreamed model, shoved out of place, deleted by another resource) and leaves the shop silently unopenable, so the ped is set dressing only
- `Config.shopPedScopeRadius` (75.0m) — the radius that creates a decorative clerk for the local player; independent of the interaction range
- `Config.shopZoneDefault` — fallback box for a shop entry added without its own `zone`
- `Config.tattoos` — the base-game overlay catalogue with per-tattoo pricing
- `Config.interactDistance` (2.0) — server-enforced proximity for shop sessions and kora_target zone range
- `Config.camera.zones` — per-zone (`full`/`face`/`torso`/`legs`/`shoes`) framing presets for the fitting-room camera
- `Config.camera.zoom` — `{ min, max, step }` bounds for free mouse-wheel zoom (metres of camera radius; `step` is per wheel notch)
- `Config.camera.orbitDegPerSec` / `Config.camera.transitionMs` — orbit and zoom-transition speeds

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
- [qbsql](https://qbcore2.github.io/kora_sql/) — database driver
- [qbcore](https://qbcore2.github.io/kora_core/) — framework core
- [qbinventory](https://qbcore2.github.io/kora_inventory/) — headless inventory
- [qbtarget](https://qbcore2.github.io/kora_target/) — targeting/interaction
- [qbadmin](https://qbcore2.github.io/kora_admin/) — admin menu
- [full resource list ↗](https://github.com/orgs/qbcore2/repositories)

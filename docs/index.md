---
layout: default
title: qbclothing
---

Illenium-style clothing, appearance and outfit wardrobe for FiveM. A player
trying on clothes at a shop, barber, hairdresser or tattoo parlour is moved
into a **private fitting-room routing bucket** (`Config.bucket.base + source`)
so nobody else can see or interact with them mid-session, with a live-orbit
camera and smooth zoom presets around the ped. Outfits are saved per citizen
(`playerskins` for the current look, `playeroutfits` for up to
`Config.wardrobe.maxOutfits` named presets) via
[qbsql](https://qbcore2.github.io/qbsql/)'s migration runner. Purchases are
priced per touched category (clothing/hair/tattoos) and charged through
[qbcore](https://qbcore2.github.io/qbcore/) money, with an optional
"clothing-as-item" mode that boxes a purchase as a physical, reusable
inventory item instead of equipping it directly. `qbclothing` `provide`s
`qb-clothing` and speaks the real upstream qb-clothing wire protocol (net
events, callback names) directly, so third-party barber/tattoo/uniform
scripts built against it keep working unmodified.

## Requirements

- [qblib](https://qbcore2.github.io/qblib/)
- [qbsql](https://qbcore2.github.io/qbsql/)
- [qbcore](https://qbcore2.github.io/qbcore/)
- [qbtarget](https://qbcore2.github.io/qbtarget/) — shop peds are targeted through qbtarget zones

## Installation

`server.cfg`, in this order:
```
set mysql_connection_string "mysql://user:pass@localhost/qbcore?charset=utf8mb4"
ensure qbsql
ensure qblib
ensure qbcore
ensure qbtarget
ensure qbclothing
```
qbclothing owns its schema (`playerskins`, `playeroutfits`) and applies
`sql/001_playerskins_outfits.sql` itself via qbsql's migration runner on first
boot — no manual SQL import needed. `fxmanifest.lua` also declares hard
`dependency` edges on qblib/qbsql/qbcore/qbtarget, so FXServer guarantees
correct start order even if `ensure` lines are reshuffled.

## Usage examples

### Open the wardrobe from another resource
```lua
-- client
exports.qbclothing:OpenWardrobe()
```

### Send a player to a specific shop by config index
```lua
-- client, e.g. from a custom "personal shopper" NPC
exports.qbclothing:OpenClothingRoom({ shopId = 3 }) -- Config.shops[3] ("Ponsonbys")
```

### Guard against opening the UI twice
```lua
-- client
if not exports.qbclothing:IsClothingMenuOpen() then
    exports.qbclothing:OpenWardrobe()
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
exports.qbclothing:OpenClothingRoom(options)  -- options = { shopId = n } or a bare number
exports.qbclothing:OpenWardrobe()
exports.qbclothing:IsClothingMenuOpen()       -- true while the fitting-room NUI is open
exports.qbclothing:GetPedModels()             -- { male = 'mp_m_freemode_01', female = 'mp_f_freemode_01' }
exports.qbclothing:ApplyAppearanceToPed(ped, model, skin) -- local preview ped; (true) or (false, err)
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

The multicharacter preview callback is pre-login safe: qbcore verifies that
the requested active character belongs to the requesting license before any
appearance is returned. Foreign and soft-deleted citizen IDs are rejected;
successful results are sanitized, rate-limited, and cached for that source's
selection session.

### Session net events
```lua
-- client -> server (qblib's tokenised QB.events gateway, not a raw
-- RegisterNetEvent -- confirmSession moves real money and requestSession
-- gates an admin-only free fitting, so these go through the per-session
-- token instead of a guessable static event name; see qblib's
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
sessions are also reachable via qbtarget zones attached to each configured
shop ped, and `qbclothing:client:openNearestShop(service)` opens the closest
shop by proximity for the given service (`'clothing'` by default, or
`'barber'`/`'tattoo'`) — used by qbadmin's self-service clothing/barber/tattoo
entries. `qbclothing:client:openAdminSession` opens a free, unrestricted
clothing+hair+tattoo session (the same `creation` service policy used for
first-character fittings); the server re-checks `admin` permission before
granting it regardless of what qbadmin's menu shows client-side.

## Config highlights (`config.lua`)

- `Config.bucket.base` (1,000,000) — fitting-room routing bucket offset, `base + source`
- `Config.shop.currency` — account charged for purchases (default `cash`)
- `Config.services` — per-service (`clothing`/`barber`/`hairdresser`/`tattoo`/`creation`) component/prop whitelists, prices and gender restrictions
- `Config.wardrobe.maxOutfits` (20) — saved-outfit cap per citizen
- `Config.clothingAsItem` (default `false`) — when `true`, a purchase/save is boxed as a `qbclothing_outfit` inventory item (via [qbinventory](https://qbcore2.github.io/qbinventory/)) instead of equipping directly
- `Config.shops` — shop ped models, coordinates, blips and which service each one offers
- `Config.tattoos` — the base-game overlay catalogue with per-tattoo pricing
- `Config.interactDistance` (2.0) — server-enforced proximity for shop sessions and qbtarget zone range
- `Config.camera` — orbit speed and per-zone (`full`/`face`/`torso`/`legs`/`shoes`) zoom presets for the fitting-room camera

## Related resources

Part of the [qbcore2](https://github.com/qbcore2) resource set:

- [qblib](https://qbcore2.github.io/qblib/) — shared helper library
- [qbsql](https://qbcore2.github.io/qbsql/) — database driver
- [qbcore](https://qbcore2.github.io/qbcore/) — framework core
- [qbinventory](https://qbcore2.github.io/qbinventory/) — headless inventory
- [qbtarget](https://qbcore2.github.io/qbtarget/) — targeting/interaction
- [qbadmin](https://qbcore2.github.io/qbadmin/) — admin menu
- [full resource list ↗](https://github.com/orgs/qbcore2/repositories)

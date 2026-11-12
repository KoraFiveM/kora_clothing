---
title: Shops and blips
sidebar_position: 7
---

## Shop entries

Each entry in `Config.shops` is one location:

```lua
{
    service = 'clothing',          -- clothing | barber | hairdresser | tattoo
    free = false,                  -- true: never charged (resolved on the server only)
    label = 'Suburban',            -- prompt text "Open <label>" and blip title
    ped = 'a_f_y_business_02',     -- decorative clerk model (Config.shopPeds) / tattoo artist fallback
    coords = vector4(127.02, -223.29, 53.56, 70.0), -- interaction and blip point, heading in .w
    points = {                     -- optional, clothing only: register and rack points
        register = vector4(125.35, -223.62, 54.56, 248.79),
        racks = vector4(121.63, -224.23, 54.56, 152.18),
    },
    zone = { size = vector3(2.2, 1.8, 2.2), rotation = 70.0 },
    blip = { enabled = true, sprite = 73, color = 3, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Suburban' },
    -- tattooPed = { ... } or false  (tattoo shops, see Tattoo studio)
}
```

`zone` can be:

- a box centred on `coords`: `{ size = vector3(...), rotation = deg }`. `rotation` defaults to `coords.w`.
- a polygon: `{ points = { vector3, ... }, thickness = n }` (thickness measured up from the lowest point) or `{ points = { ... }, minZ = n, maxZ = n }`.

A shop without `zone` uses `Config.shopZoneDefault`.

The default config ships 6 clothing shops (Suburban, Ponsonbys, Binco, two of each), 6 tattoo shops, 2 barbers and 2 hairdressers.

## Opening a shop

`Config.interactionMode` (read at start):

- `'textui'` (default): while inside the shop area, kora_lib TextUI shows `[E] Open <label>`. Pressing the `kora_clothing_open_shop` keybind (default `E`) opens the shop. The prompt is hidden while a session is open.
- `'target'`: a kora_target zone with the option "Open `label`" (range `Config.interactDistance`). `Config.showTargetHints` can force the zone icon on or off.

With `Config.clothingShopPoints` (default on), clothing shops that have `points` open from a sphere of `Config.clothingPointRadius` (5 m) around the register and the racks instead of their zone.

## Reach check

The server checks that the player is close enough before opening a shop session:

- For register and rack shops: within `clothingPointRadius + 1` m of either point.
- Otherwise: inside the zone, or within `Config.interactDistance + 1` m of it.

If the player is too far, they get "Move closer to the `label` to open it."

The `kora_clothing:client:openNearestShop` event (and `qb-clothing:client:openMenu` with no argument) chooses the nearest shop of the given service on the client, measured from `coords` or the register and rack points. It refuses with "You are not near a ... shop" outside `interactDistance + 1` m.

## Decorative clerks

`Config.shopPeds = true` spawns `shop.ped` at each shop, client-local and frozen, only while the player is within `Config.shopPedScopeRadius` (75 m). The clerk has no interaction: shops always open from the zone or prompt, so a missing or moved ped never makes a shop unusable. Tattoo shops that have an artist ped do not get a clerk.

## Blips

Shops with `blip.enabled` get a kora_lib blip (`Kora.blips.create(shop.coords, shop.blip)`). The default config groups them with `category`: `Clothing`, `Tattoo` and `Grooming` (barbers and hairdressers share it). Clothing shops also set `name` (Suburban, Ponsonbys, Binco). Unless `blip.info` is set, the blip info panel shows the shop label, the service, and either "This service is free." or "Browse and purchase available customisations."

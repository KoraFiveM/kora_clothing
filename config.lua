-- Own config, self-contained -- matches qbmultichar's convention of owning
-- its data rather than reading qbcore's shared registries. Named `Config`,
-- not a `QB`-prefixed global -- qblib's `@qblib/init.lua` already owns the
-- global `QB` as a live cross-resource proxy in this codebase.

Config = {}

-- Every fitting-room bucket is `Config.bucket.base + source`. `source` is a
-- small per-connection integer (FiveM reuses low slot numbers), so this stays
-- far below any world/instance bucket another resource might use starting
-- from 0, while remaining unique per concurrent session.
Config.bucket = {
    base = 1000000,
}

-- Flat per-category price, matching real qb-clothing's "you pay for whichever
-- categories you actually changed" shop model. Charged server-side on
-- confirm, computed from a diff against the player's last-saved skin -- never
-- trusted from the NUI. `cash`-only by default; real qb-clothing supports a
-- configurable currency, exposed here as Config.shop.currency.
Config.shop = {
    currency = 'cash',
    prices = {
        tops = 175,
        legs = 150,
        shoes = 120,
        body = 90,       -- face/mask/hair changes, priced as a single "styling" category
        accessories = 60, -- bags/accessories/badges/hats/glasses/ears/watches/bracelets
    },
}

Config.wardrobe = {
    maxOutfits = 20,
}

-- When true, a purchase/save that would normally equip the outfit directly
-- instead gives the player a physical inventory item holding that exact
-- model+skin; using the item from inventory is what actually puts it on.
-- Off by default -- direct-equip needs no qbinventory item definitions to
-- exist, so this is a safe default for a server not running qbinventory or
-- not wanting a wardrobe-as-inventory economy. Requires qbinventory running
-- when enabled; qbclothing registers the item with qbcore and its use
-- handler with qbinventory itself, no server-side setup needed beyond
-- flipping this on.
Config.clothingAsItem = false

Config.clothingItem = {
    name = 'qbclothing_outfit',
    label = 'Outfit',
    weight = 300,
    image = 'qbclothing_outfit.png',
    description = 'A saved outfit. Use it to put it on.',
}

-- Fixed shop locations. Each entry spawns a clerk ped (qblib's QB.entities)
-- and a qbtarget zone on it that opens the shop menu for whichever gender
-- catalogue the player's current model implies. `blip` is optional per shop
-- (qbinventory's config/shops/ammunation.lua convention) -- set `enabled =
-- false` to skip map-blip creation for a given store while keeping the ped.
Config.shops = {
    {
        label = 'Suburban',
        ped = 'a_f_y_business_02',
        coords = vector4(127.02, -223.29, 54.56, 70.0),
        blip = { enabled = true, sprite = 73, color = 3, scale = 0.8, shortRange = true, label = 'Suburban' },
    },
    {
        label = 'Suburban',
        ped = 'a_f_y_business_04',
        coords = vector4(72.32, -1399.2, 29.38, 0.0),
        blip = { enabled = true, sprite = 73, color = 3, scale = 0.8, shortRange = true, label = 'Suburban' },
    },
    {
        label = 'Ponsonbys',
        ped = 'a_m_y_business_03',
        coords = vector4(-708.61, -152.85, 37.42, 30.0),
        blip = { enabled = true, sprite = 73, color = 27, scale = 0.8, shortRange = true, label = 'Ponsonbys' },
    },
    {
        label = 'Ponsonbys',
        ped = 'a_f_y_business_01',
        coords = vector4(-167.79, -299.05, 39.73, 250.0),
        blip = { enabled = true, sprite = 73, color = 27, scale = 0.8, shortRange = true, label = 'Ponsonbys' },
    },
    {
        label = 'Binco',
        ped = 'a_m_y_business_02',
        coords = vector4(-1193.44, -772.12, 17.32, 130.0),
        blip = { enabled = true, sprite = 73, color = 5, scale = 0.8, shortRange = true, label = 'Binco' },
    },
    {
        label = 'Binco',
        ped = 'a_f_y_hipster_02',
        coords = vector4(-827.86, -1073.75, 10.33, 130.0),
        blip = { enabled = true, sprite = 73, color = 5, scale = 0.8, shortRange = true, label = 'Binco' },
    },
}

Config.interactDistance = 2.0

-- Camera zoom presets the NUI can request via the `qbclothing:nui:camera`
-- callback. Offsets are relative to the ped's mid-spine bone in the ped's own
-- forward-facing frame; client/camera.lua turns these into world-space coords
-- every frame so they track ped rotation during the live orbit.
Config.camera = {
    zones = {
        full  = { boneOffset = vector3(0.0, 0.0, 0.0),  camOffset = vector3(0.0, 2.2, 0.3),  fov = 45.0 },
        face  = { boneOffset = vector3(0.0, 0.0, 0.62), camOffset = vector3(0.0, 0.65, 0.05), fov = 30.0 },
        torso = { boneOffset = vector3(0.0, 0.0, 0.42), camOffset = vector3(0.0, 1.1, 0.05),  fov = 35.0 },
        legs  = { boneOffset = vector3(0.0, 0.0, -0.2), camOffset = vector3(0.0, 1.3, 0.05),  fov = 35.0 },
        shoes = { boneOffset = vector3(0.0, 0.0, -0.85),camOffset = vector3(0.0, 1.1, -0.15), fov = 35.0 },
    },
    -- Orbit rotation and zoom-transition speeds, tuned for the "smooth, not a
    -- jump-cut" illenium-style feel called for by UX.
    orbitDegPerSec = 90.0,
    transitionMs = 350,
}

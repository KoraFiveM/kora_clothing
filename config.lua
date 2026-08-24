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

-- Currency is shared by every paid service. Prices live beside the service
-- policy below because hair and tattoos price differently from clothing.
Config.shop = {
    currency = 'cash',
}

-- Service policy is deliberately separate from locations. A shop chooses one
-- of these services, while its own `free` flag is the only client-visible
-- pricing override. Component/prop IDs are whitelists; omitted IDs are
-- retained from the saved appearance when a specialist session confirms.
Config.services = {
    clothing = {
        components = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
        props = { 0, 1, 2, 6, 7 },
        prices = { tops = 175, legs = 150, shoes = 120, body = 90, accessories = 60 },
    },
    barber = { components = { 2 }, props = {}, model = 'male', prices = { body = 90 } },
    hairdresser = { components = { 2 }, props = {}, model = 'female', prices = { body = 90 } },
    tattoo = { components = {}, props = {}, tattoos = true },
    -- Character creation is the only normal flow that exposes face, clothing,
    -- hair, and tattoos together. It is always free and mandatory.
    creation = { all = true, tattoos = true },
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

-- Fixed service locations. Each entry spawns a clerk and target zone. `free`
-- is resolved only by the server from this config; callers cannot forge it.
Config.shops = {
    {
        service = 'clothing', free = false, label = 'Suburban',
        ped = 'a_f_y_business_02',
        coords = vector4(127.02, -223.29, 53.56, 70.0),
        blip = { enabled = true, sprite = 73, color = 3, scale = 0.8, shortRange = true, label = 'Suburban' },
    },
    {
        service = 'clothing', free = false, label = 'Suburban',
        ped = 'a_f_y_business_04',
        coords = vector4(72.32, -1399.2, 28.38, 0.0),
        blip = { enabled = true, sprite = 73, color = 3, scale = 0.8, shortRange = true, label = 'Suburban' },
    },
    {
        service = 'clothing', free = false, label = 'Ponsonbys',
        ped = 'a_m_y_business_03',
        coords = vector4(-708.61, -152.85, 36.42, 30.0),
        blip = { enabled = true, sprite = 73, color = 27, scale = 0.8, shortRange = true, label = 'Ponsonbys' },
    },
    {
        service = 'clothing', free = false, label = 'Ponsonbys',
        ped = 'a_f_y_business_01',
        coords = vector4(-167.79, -299.05, 38.73, 250.0),
        blip = { enabled = true, sprite = 73, color = 27, scale = 0.8, shortRange = true, label = 'Ponsonbys' },
    },
    {
        service = 'clothing', free = false, label = 'Binco',
        ped = 'a_m_y_business_02',
        coords = vector4(-1193.44, -772.12, 16.32, 130.0),
        blip = { enabled = true, sprite = 73, color = 5, scale = 0.8, shortRange = true, label = 'Binco' },
    },
    {
        service = 'clothing', free = false, label = 'Binco',
        ped = 'a_f_y_hipster_02',
        coords = vector4(-827.86, -1073.75, 9.33, 130.0),
        blip = { enabled = true, sprite = 73, color = 5, scale = 0.8, shortRange = true, label = 'Binco' },
    },
    { service = 'tattoo', free = false, label = 'Tattoo Artist', ped = 'u_m_y_tattoo_01', coords = vector4(1322.6, -1651.9, 52.28, 130.0), blip = { enabled = true, sprite = 75, color = 1, scale = 0.8, shortRange = true, label = 'Tattoo Artist' } },
    { service = 'tattoo', free = false, label = 'Tattoo Artist', ped = 'u_m_y_tattoo_01', coords = vector4(-1153.6, -1425.7, 4.95, 120.0), blip = { enabled = true, sprite = 75, color = 1, scale = 0.8, shortRange = true, label = 'Tattoo Artist' } },
    { service = 'barber', free = false, label = 'Barber', ped = 's_m_m_hairdress_01', coords = vector4(-814.3, -183.8, 36.57, 120.0), blip = { enabled = true, sprite = 71, color = 0, scale = 0.8, shortRange = true, label = 'Barber' } },
    { service = 'barber', free = false, label = 'Barber', ped = 's_m_m_hairdress_01', coords = vector4(1211.0, -470.9, 65.21, 75.0), blip = { enabled = true, sprite = 71, color = 0, scale = 0.8, shortRange = true, label = 'Barber' } },
    { service = 'hairdresser', free = false, label = 'Hairdresser', ped = 's_f_m_fembarber', coords = vector4(136.8, -1708.4, 28.29, 50.0), blip = { enabled = true, sprite = 71, color = 0, scale = 0.8, shortRange = true, label = 'Hairdresser' } },
    { service = 'hairdresser', free = false, label = 'Hairdresser', ped = 's_f_m_fembarber', coords = vector4(-1282.6, -1116.8, 5.99, 90.0), blip = { enabled = true, sprite = 71, color = 0, scale = 0.8, shortRange = true, label = 'Hairdresser' } },
}

-- The catalogue is config-owned: server owners can remove entries or alter
-- their individual price without changing code. Each overlay is native GTA
-- base-game content. Entries missing one model's overlay simply do not appear
-- for that model. The shape intentionally scales to the full base-game list.
Config.tattoos = {
    { id = 'airraces_turbulence', label = 'Turbulence', group = 'Torso', collection = 'mpairraces_overlays', male = 'MP_Airraces_Tattoo_000_M', female = 'MP_Airraces_Tattoo_000_F', price = 125 },
    { id = 'airraces_pilot_skull', label = 'Pilot Skull', group = 'Torso', collection = 'mpairraces_overlays', male = 'MP_Airraces_Tattoo_001_M', female = 'MP_Airraces_Tattoo_001_F', price = 125 },
    { id = 'airraces_winged_bombshell', label = 'Winged Bombshell', group = 'Torso', collection = 'mpairraces_overlays', male = 'MP_Airraces_Tattoo_002_M', female = 'MP_Airraces_Tattoo_002_F', price = 125 },
    { id = 'beach_ship_arms', label = 'Ship Arms', group = 'Arms', collection = 'mpbeach_overlays', male = 'MP_Bea_M_Back_000', price = 110 },
    { id = 'beach_tribal_hammerhead', label = 'Tribal Hammerhead', group = 'Torso', collection = 'mpbeach_overlays', male = 'MP_Bea_M_Chest_000', price = 110 },
    { id = 'beach_tribal_shark', label = 'Tribal Shark', group = 'Torso', collection = 'mpbeach_overlays', male = 'MP_Bea_M_Chest_001', price = 110 },
    { id = 'beach_dolphin', label = 'Dolphin', group = 'Legs', collection = 'mpbeach_overlays', female = 'MP_Bea_F_Leg_000', price = 110 },
    { id = 'beach_seashell', label = 'Seashell', group = 'Torso', collection = 'mpbeach_overlays', female = 'MP_Bea_F_Back_000', price = 110 },
    { id = 'business_moneybag', label = 'Money Bag', group = 'Arms', collection = 'mpbusiness_overlays', male = 'MP_Buis_M_Arml_000', female = 'MP_Buis_F_Arml_000', price = 140 },
    { id = 'business_diamond', label = 'Diamond', group = 'Arms', collection = 'mpbusiness_overlays', male = 'MP_Buis_M_Arm_000', female = 'MP_Buis_F_Arm_000', price = 140 },
    { id = 'business_luxury', label = 'Luxury', group = 'Torso', collection = 'mpbusiness_overlays', male = 'MP_Buis_M_Chest_000', female = 'MP_Buis_F_Chest_000', price = 140 },
    { id = 'hipster_anchor', label = 'Anchor', group = 'Arms', collection = 'mphipster_overlays', male = 'FM_Hip_M_Tat_000', female = 'FM_Hip_F_Tat_000', price = 130 },
    { id = 'hipster_geometric', label = 'Geometric', group = 'Arms', collection = 'mphipster_overlays', male = 'FM_Hip_M_Tat_004', female = 'FM_Hip_F_Tat_004', price = 130 },
    { id = 'hipster_rose', label = 'Rose', group = 'Torso', collection = 'mphipster_overlays', male = 'FM_Hip_M_Tat_013', female = 'FM_Hip_F_Tat_013', price = 130 },
    { id = 'importexport_skull', label = 'Skull', group = 'Head', collection = 'mpimportexport_overlays', male = 'MP_MP_ImportExport_Tat_000_M', female = 'MP_MP_ImportExport_Tat_000_F', price = 150 },
    { id = 'importexport_wings', label = 'Wings', group = 'Back', collection = 'mpimportexport_overlays', male = 'MP_MP_ImportExport_Tat_001_M', female = 'MP_MP_ImportExport_Tat_001_F', price = 150 },
}

-- Component variations applied for the duration of a tattoo session only
-- (captured and restored around them, never persisted) so every catalogue
-- group -- Head/Torso/Arms/Back/Legs -- is actually visible while browsing
-- instead of hidden under whatever the player walked in wearing. These are
-- the standard freemode "swimwear/underwear" drawables and are stable base-
-- game content (DLC only appends new indices after them, never reorders),
-- but verify in-game and adjust per gender if a clothing pack this server
-- runs happens to shift what looks best here.
Config.tattooStrip = {
    male = {
        [1]  = { d = 0,  t = 0 }, -- mask: none
        [3]  = { d = 15, t = 0 }, -- torso: bare chest
        [4]  = { d = 21, t = 0 }, -- legs: boxers
        [8]  = { d = 15, t = 0 }, -- undershirt: none
        [11] = { d = 0,  t = 0 }, -- torso 2 (decal overlay): none
    },
    female = {
        [1]  = { d = 0,  t = 0 },
        [3]  = { d = 14, t = 0 },
        [4]  = { d = 15, t = 0 },
        [8]  = { d = 15, t = 0 },
        [11] = { d = 0,  t = 0 },
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

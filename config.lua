-- Own config, self-contained -- matches kora_multichar's convention of owning
-- its data rather than reading kora_core's shared registries. Named `Config`,
-- not a `QB`-prefixed global -- kora_lib's `@kora_lib/init.lua` already owns the
-- global `QB` as a live cross-resource proxy in this codebase.

Config = {}

-- Descriptors make a setting editable in kora_lib's config workspace and are
-- resolved back to plain values by QB.config.adopt at the end of this file.
-- Without kora_lib's config module the plain defaults after `or` are used.
local config = QB and QB.config

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
        -- Component 1 is GTA's mask slot; this server's facial-hair assets
        -- use it, so keeping it out of the general clothing menu prevents
        -- facial hair from being changed there.
        components = { 3, 4, 5, 6, 7, 8, 9, 10, 11 },
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

-- Which head overlays players can edit, per kind of session: `creator` is
-- character creation (and admin sessions), `barber` is the barber/hairdresser.
-- A category set to false is hidden in the menu and ignored by the client and
-- the server. Skin tone stays creation-only and is not configurable here.
Config.headOverlays = {
    eyebrows = {
        creator = config and config.boolean(true, {
            label = 'Eyebrows in character creation',
            description = 'Lets players choose eyebrow style, opacity and colour while creating a character. Turn off to hide eyebrow options from creation.',
            live = true,
        }) or true,
        barber = config and config.boolean(true, {
            label = 'Eyebrows at the barber',
            description = 'Lets players change eyebrow style, opacity and colour at barbers and hairdressers, charged at the hair price. Turn off to hide eyebrow options there.',
            live = true,
        }) or true,
    },
    facialHair = {
        creator = config and config.boolean(true, {
            label = 'Facial hair in character creation',
            description = 'Lets players choose facial hair style, opacity and colour while creating a character. Turn off to hide facial hair options from creation.',
            live = true,
        }) or true,
        barber = config and config.boolean(true, {
            label = 'Facial hair at the barber',
            description = 'Lets players change facial hair style, opacity and colour at barbers and hairdressers, charged at the hair price. Turn off to hide facial hair options there.',
            live = true,
        }) or true,
    },
}

Config.wardrobe = {
    maxOutfits = 20,
}

-- When true, a purchase/save that would normally equip the outfit directly
-- instead gives the player a physical inventory item holding that exact
-- model+skin; using the item from inventory is what actually puts it on.
-- Off by default -- direct-equip needs no kora_inventory item definitions to
-- exist, so this is a safe default for a server not running kora_inventory or
-- not wanting a wardrobe-as-inventory economy. Requires kora_inventory running
-- when enabled; kora_clothing registers the item with kora_core and its use
-- handler with kora_inventory itself, no server-side setup needed beyond
-- flipping this on.
Config.clothingAsItem = false

Config.clothingItem = {
    name = 'qbclothing_outfit',
    label = 'Outfit',
    weight = 300,
    image = 'qbclothing_outfit.png',
    description = 'A saved outfit. Use it to put it on.',
}

-- Decorative shop clerks. Off by default: the target is a zone on the
-- storefront itself (see Config.shops[n].zone), so the ped is pure set
-- dressing. It is client-local and scoped below, so distant shops do not
-- occupy a GTA entity slot or stream their model. Turn it on if the empty
-- counters look wrong on this server's map; nothing else changes when you do.
Config.shopPeds = false

-- Local players spawn a decorative clerk on entering this radius and delete it
-- again on exit. This is independent from Config.interactDistance: the shop
-- target remains the storefront zone and is always available.
Config.shopPedScopeRadius = 75.0

-- Fixed service locations. Each entry creates a kora_target zone; `free` is
-- resolved only by the server from this config, so callers cannot forge it.
--
-- `coords` is the interaction/blip point (heading in `.w`, used for the clerk
-- when Config.shopPeds is on). `zone` is the target geometry: either a
-- `{ points, thickness }` / `{ points, minZ, maxZ }` polygon, or a
-- `{ size, rotation }` box centred on `coords`.
--
-- Clothing stores are POLYGONS covering the walkable shop interior, not a
-- counter box: the player browses the whole floor, so anywhere inside the
-- store should open the shop rather than one 2m spot by the till. Polys are
-- captured in-game with kora_lib's zone creator (`QB.zones.poly` output pasted
-- verbatim), so the shape matches the real map geometry. `thickness` is
-- measured UPWARD from the lowest point, not centred on the average -- see
-- kora_lib/modules/zones/client.lua -- so 4.0 is one storey of headroom above
-- the floor the points were traced on. Barber and tattoo zones are kept tight
-- around their chair, but remain polygons so every service location uses the
-- same target-zone primitive.
--
-- A named category groups every branch of a service beneath one pause-map
-- legend heading. Clothing shops also supply their storefront name separately,
-- while generic Tattoo and Grooming services need no duplicate name. The
-- shop's own `label` below remains the target prompt.
Config.shops = {
    {
        service = 'clothing', free = false, label = 'Suburban',
        ped = 'a_f_y_business_02',
        coords = vector4(127.02, -223.29, 53.56, 70.0),
        zone = {
            points = {
                vector3(133.37, -210.23, 53.78),
                vector3(131.93, -209.57, 53.56),
                vector3(130.20, -210.37, 53.56),
                vector3(129.33, -212.63, 53.56),
                vector3(124.86, -210.91, 53.61),
                vector3(125.56, -208.61, 53.56),
                vector3(124.80, -206.68, 53.59),
                vector3(123.50, -206.37, 53.56),
                vector3(116.04, -228.30, 53.56),
                vector3(118.26, -229.34, 53.56),
                vector3(116.54, -234.23, 53.56),
                vector3(118.24, -234.85, 53.64),
                vector3(120.09, -230.02, 53.58),
                vector3(124.54, -230.75, 55.55),
                vector3(125.95, -227.58, 55.34),
                vector3(127.26, -228.03, 56.45),
            },
            thickness = 4.00,
        },
        blip = { enabled = true, sprite = 73, color = 3, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Suburban' },
    },
    {
        service = 'clothing', free = false, label = 'Suburban',
        ped = 'a_f_y_business_04',
        coords = vector4(72.32, -1399.2, 28.38, 0.0),
        zone = { size = vector3(2.2, 1.8, 2.2), rotation = 0.0 },
        blip = { enabled = true, sprite = 73, color = 3, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Suburban' },
    },
    {
        service = 'clothing', free = false, label = 'Ponsonbys',
        ped = 'a_m_y_business_03',
        coords = vector4(-708.61, -152.85, 36.42, 30.0),
        zone = { size = vector3(2.2, 1.8, 2.2), rotation = 30.0 },
        blip = { enabled = true, sprite = 73, color = 27, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Ponsonbys' },
    },
    {
        service = 'clothing', free = false, label = 'Ponsonbys',
        ped = 'a_f_y_business_01',
        coords = vector4(-167.79, -299.05, 38.73, 250.0),
        zone = { size = vector3(2.2, 1.8, 2.2), rotation = 250.0 },
        blip = { enabled = true, sprite = 73, color = 27, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Ponsonbys' },
    },
    {
        service = 'clothing', free = false, label = 'Binco',
        ped = 'a_m_y_business_02',
        coords = vector4(-1193.44, -772.12, 16.32, 130.0),
        zone = { size = vector3(2.2, 1.8, 2.2), rotation = 130.0 },
        blip = { enabled = true, sprite = 73, color = 5, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Binco' },
    },
    {
        service = 'clothing', free = false, label = 'Binco',
        ped = 'a_f_y_hipster_02',
        coords = vector4(-827.86, -1073.75, 9.33, 130.0),
        zone = { size = vector3(2.2, 1.8, 2.2), rotation = 130.0 },
        blip = { enabled = true, sprite = 73, color = 5, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Binco' },
    },
    {
        service = 'tattoo', free = false, label = 'Tattoo Artist',
        ped = 'u_m_y_tattoo_01',
        coords = vector4(1322.6, -1651.9, 52.28, 130.0),
        zone = {
            points = {
                vector3(1321.19, -1651.78, 52.28),
                vector3(1322.48, -1653.31, 52.28),
                vector3(1324.01, -1652.02, 52.28),
                vector3(1322.72, -1650.49, 52.28),
            },
            minZ = 51.18, maxZ = 53.38,
        },
        blip = { enabled = true, sprite = 75, color = 1, scale = 0.8, shortRange = true, category = 'Tattoo' },
    },
    {
        service = 'tattoo', free = false, label = 'Tattoo Artist',
        ped = 'u_m_y_tattoo_01',
        coords = vector4(-1153.6, -1425.7, 4.95, 120.0),
        zone = {
            points = {
                vector3(-1154.97, -1425.33, 4.95),
                vector3(-1153.97, -1427.07, 4.95),
                vector3(-1152.23, -1426.07, 4.95),
                vector3(-1153.23, -1424.33, 4.95),
            },
            minZ = 3.85, maxZ = 6.05,
        },
        blip = { enabled = true, sprite = 75, color = 1, scale = 0.8, shortRange = true, category = 'Tattoo' },
    },
    {
        service = 'barber', free = false, label = 'Barber',
        ped = 's_m_m_hairdress_01',
        coords = vector4(-814.3, -183.8, 36.57, 120.0),
        zone = {
            points = {
                vector3(-815.67, -183.43, 36.57),
                vector3(-814.67, -185.17, 36.57),
                vector3(-812.93, -184.17, 36.57),
                vector3(-813.93, -182.43, 36.57),
            },
            minZ = 35.47, maxZ = 37.67,
        },
        blip = { enabled = true, sprite = 71, color = 0, scale = 0.8, shortRange = true, category = 'Grooming' },
    },
    {
        service = 'barber', free = false, label = 'Barber',
        ped = 's_m_m_hairdress_01',
        coords = vector4(1211.0, -470.9, 65.21, 75.0),
        zone = {
            points = {
                vector3(1210.29, -469.68, 65.21),
                vector3(1209.78, -471.61, 65.21),
                vector3(1211.71, -472.12, 65.21),
                vector3(1212.22, -470.19, 65.21),
            },
            minZ = 64.11, maxZ = 66.31,
        },
        blip = { enabled = true, sprite = 71, color = 0, scale = 0.8, shortRange = true, category = 'Grooming' },
    },
    {
        service = 'hairdresser', free = false, label = 'Hairdresser',
        ped = 's_f_m_fembarber',
        coords = vector4(136.8, -1708.4, 28.29, 50.0),
        zone = { size = vector3(2.0, 1.6, 2.2), rotation = 50.0 },
        blip = { enabled = true, sprite = 71, color = 0, scale = 0.8, shortRange = true, category = 'Grooming' },
    },
    {
        service = 'hairdresser', free = false, label = 'Hairdresser',
        ped = 's_f_m_fembarber',
        coords = vector4(-1282.6, -1116.8, 5.99, 90.0),
        zone = { size = vector3(2.0, 1.6, 2.2), rotation = 90.0 },
        blip = { enabled = true, sprite = 71, color = 0, scale = 0.8, shortRange = true, category = 'Grooming' },
    },
}

-- Fallback box for a shop entry a server owner added without its own `zone`.
-- Better than skipping the target entirely: an unreachable shop reads as a
-- broken resource, and a 2m counter box is right often enough to be a usable
-- default at the coords they already had to supply.
Config.shopZoneDefault = { size = vector3(2.0, 1.6, 2.2) }

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

-- Hides the minimap while any clothing menu (shop, barber, tattoo, creator,
-- wardrobe) is open and restores it afterwards. Only used when kora_hud is not
-- running; kora_hud hides the radar itself.
Config.hideRadarInMenu = config and config.boolean(true, {
    label = 'Hide radar in menus',
    description = 'Hides the minimap while a clothing, barber, tattoo or character creation menu is open, then shows it again. Only applies when kora_hud is not running, because kora_hud already hides the radar itself.',
    live = true,
}) or true

-- How players open a shop. 'target' uses a kora_target zone option; 'textui'
-- shows "[E] Open <shop>" through kora_lib's TextUI while inside the shop zone
-- and opens on E. Read when the resource starts.
Config.interactionMode = config and config.enum('target', {
    label = 'Shop interaction',
    description = 'Chooses how players open a shop. Target Zone uses the kora_target prompt; Text Prompt shows an [E] Open message while standing inside the shop area. Changes apply after the resource restarts.',
    options = {
        { value = 'target', label = 'Target Zone' },
        { value = 'textui', label = 'Text Prompt' },
    },
}) or 'target'

-- Whether shop target zones draw their world icon. nil follows kora_target's
-- own icon setting; true always draws it for shop zones; false never does.
-- Read when the zones are registered at resource start.
Config.showTargetHints = config and config.optional(nil, config.boolean(true), {
    label = 'Show shop target icons',
    description = "Forces the world icon on shop target zones on (set) or off. Leave unset to follow kora_target's own icon setting. Applies after the resource restarts.",
}) or nil

-- Captures the mouse while dragging to rotate the ped so the cursor cannot leave
-- the screen. Read each time the menu opens; the NUI falls back to a plain drag
-- if the game refuses the lock.
Config.rotatePointerLock = config and config.boolean(true, {
    label = 'Capture mouse while rotating',
    description = 'Locks the mouse while you hold click to rotate the character in clothing, barber, tattoo and creation menus, so rotation continues without lifting the button. Turn off to use a plain drag.',
    live = true,
}) or true

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
    -- Free mouse-wheel zoom, applied as an OFFSET on top of whichever zone
    -- preset is selected (the presets stay jump-to shortcuts). `step` is
    -- metres of radius per wheel notch; `min`/`max` bound the resulting
    -- radius, not the offset. `min` is deliberately not near zero -- inside
    -- roughly 0.4m the camera is inside the ped's own head and renders the
    -- inside of the face mesh.
    zoom = {
        min = 0.45,
        max = 4.5,
        step = 0.12,
    },
    -- Which zone each menu category frames when the player picks it. Clothing
    -- groups and tattoo groups are looked up by their exact UI names. Arms and
    -- Back fall back to the torso framing because there is no per-limb preset.
    categoryZones = {
        tops = 'torso', legs = 'legs', shoes = 'shoes', body = 'face', accessories = 'full',
        Head = 'face', Torso = 'torso', Arms = 'torso', Back = 'torso', Legs = 'legs',
    },
    -- When true, choosing a category (or a tattoo) jumps the camera to that
    -- category's zone and drops any wheel zoom, so a close-up from one
    -- category never carries over to the next. When false the camera stays
    -- exactly where the player left it until they use the zone buttons.
    resetOnCategoryChange = config and config.boolean(true, {
        label = 'Reset camera when changing category',
        description = 'Moves the fitting-room camera to the framing for each clothing or tattoo category when it is selected, and clears any mouse-wheel zoom. Turn off to keep the camera where the player put it.',
        live = true,
    }) or true,
    -- Orbit rotation and zoom-transition speeds, tuned for the "smooth, not a
    -- jump-cut" illenium-style feel called for by UX.
    orbitDegPerSec = 90.0,
    transitionMs = 350,
}

-- Registers this resource-owned configuration with kora_lib without changing its public Config table.
if QB and QB.config and QB.config.adopt then
    local tattooStripItem = QB.config.object({
        d = QB.config.integer(0, { min = 0 }),
        t = QB.config.integer(0, { min = 0 }),
    })
    Config.tattooStrip.male = QB.config.map(Config.tattooStrip.male, tattooStripItem, {
        keyType = 'integer',
        live = true,
        label = 'Male tattoo preview clothing',
        description = 'Maps GTA clothing component IDs to temporary drawable (d) and texture (t) variations used while a male freemode character previews tattoos. Add only valid non-negative component, drawable, and texture IDs; the original outfit is restored when the tattoo session closes.',
    })
    Config.tattooStrip.female = QB.config.map(Config.tattooStrip.female, tattooStripItem, {
        keyType = 'integer',
        live = true,
        label = 'Female tattoo preview clothing',
        description = 'Maps GTA clothing component IDs to temporary drawable (d) and texture (t) variations used while a female freemode character previews tattoos. Add only valid non-negative component, drawable, and texture IDs; the original outfit is restored when the tattoo session closes.',
    })
    Config = QB.config.adopt(Config)
end

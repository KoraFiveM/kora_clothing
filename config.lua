-- Own config, self-contained -- matches kora_multichar's convention of owning
-- its data rather than reading kora_core's shared registries. Named `Config`,
-- not a `Kora`-prefixed global -- kora_lib's `@kora_lib/init.lua` already owns the
-- global `Kora` as a live cross-resource proxy in this codebase.

Config = {}

-- Descriptors make a setting editable in kora_lib's config workspace and are
-- resolved back to plain values by Kora.config.adopt at the end of this file.
-- Without kora_lib's config module the plain defaults after `or` are used.
local config = Kora and Kora.config

-- Every fitting-room bucket is `Config.bucket.base + source`. `source` is a
-- small per-connection integer (FiveM reuses low slot numbers), so this stays
-- far below any world/instance bucket another resource might use starting
-- from 0, while remaining unique per concurrent session.
--   disablePopulation : turn ambient peds and vehicles (traffic, jet skis,
--                       pedestrians) off inside the first-character fitting
--                       room bucket, so they do not wander through the
--                       background of character creation. Only that personal
--                       bucket is affected, never the normal world. Shop,
--                       barber and wardrobe sessions keep their population.
--                       Read each time a fitting room is entered.
Config.bucket = {
    base = 1000000,
    disablePopulation = config and config.boolean(true, {
        label = 'Disable ambient population in the first-character fitting room',
        description = 'When enabled, ambient peds and vehicles (traffic, jet skis, pedestrians) are switched off inside the private routing bucket used for the one-time first-character fitting room, so they do not wander through the creation scene. Only that personal bucket is affected, never the normal world, and shop, barber and wardrobe sessions are unchanged. Applies the next time a first-character fitting room opens.',
        live = true,
    }) or true,
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
        -- Off (default): eyebrows have their own colour palette, independent of the
        -- hair colour. Characters saved before that palette existed have no eyebrow
        -- colour of their own and keep matching their hair until a colour is picked
        -- (or Match hair colour is chosen). On: the eyebrow palette is hidden and
        -- eyebrows always take the primary hair colour, the old behaviour.
        followHairColor = config and config.boolean(false, {
            label = 'Eyebrows follow hair colour',
            description = 'Off (default): players pick an eyebrow colour of their own, separate from hair colour. On: no eyebrow colour palette is shown and eyebrows always use the primary hair colour. Applies to character creation and barbers.',
            live = true,
        }) or false,
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
-- captured in-game with kora_lib's zone creator (`Kora.zones.poly` output pasted
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
        [11] = { d = 15, t = 0 }, -- top / jacket: none (drawable 0 is a plain t-shirt)
    },
    female = {
        [1]  = { d = 0,  t = 0 },
        [3]  = { d = 14, t = 0 },
        [4]  = { d = 15, t = 0 },
        [8]  = { d = 15, t = 0 },
        [11] = { d = 15, t = 0 },
    },
}

-- Tattoo studio options.
--
-- `undress` : the studio previews tattoos on bare skin. The buttons at the
-- bottom of the menu let the player take clothing off and put it back while
-- they look. It is a PREVIEW ONLY: the changes live on the local ped, are never
-- sent to the server, never saved into the outfit and never charged, and the
-- original clothing is put back exactly when the menu closes (confirm, cancel,
-- Esc, death or a resource stop).
--
-- `allowStacking`, `maxStack`, `stackPriceMultiplier` : a tattoo can be applied
-- more than once to darken it. The skin keeps the same tattoo id repeated, one
-- entry per instance. The server validates every instance, caps each tattoo at
-- `maxStack` and prices each added instance itself.
--
-- `peds`    : an optional tattoo artist standing in each tattoo shop. Targeting
-- the artist ("Get tattooed") opens the same studio as the shop's zone, which
-- keeps working. While the studio is open the artist is faded out locally so
-- they do not block the view.
Config.tattoo = {
    -- Duplicate button in the studio list. Off keeps one instance per tattoo
    -- (extra instances are dropped server-side). Read each time a skin is
    -- sanitised or the studio opens.
    allowStacking = config and config.boolean(true, {
        label = 'Allow stacking tattoos',
        description = 'Lets players apply the same tattoo more than once (a copy button appears on applied tattoos) so it renders darker. Turn off to allow one instance of each tattoo; extra instances in saved skins are dropped.',
        live = true,
    }) or true,
    -- Most instances of ONE tattoo on a player. Three is visibly darker without
    -- turning the body solid black; clamped to 1-10.
    maxStack = config and config.integer(3, {
        min = 1, max = 10,
        label = 'Maximum tattoo stack',
        description = 'Most times the same tattoo can be applied to one character. The server enforces it, so extra copies in a saved or submitted skin are dropped.',
        live = true,
    }) or 3,
    -- 1.0 = every added instance costs the tattoo price, like a new tattoo.
    stackPriceMultiplier = config and config.number(1.0, {
        min = 0.0, max = 10.0,
        label = 'Stacked tattoo price multiplier',
        description = 'Multiplies the tattoo price for each extra copy of a tattoo beyond the first. 1.0 charges the full price again, 0.5 half price, 0 makes extra copies free. Existing copies are never charged again.',
        live = true,
    }) or 1.0,
    undress = {
        -- Off falls back to the old behaviour: the studio always strips to
        -- Config.tattooStrip on open and offers no buttons. Read each time the
        -- studio opens.
        enabled = config and config.boolean(true, {
            label = 'Tattoo studio undress buttons',
            description = 'Shows clothing buttons (top, legs, shoes, headwear, undress all) in the tattoo studio so players can see tattoos under their clothes. Preview only: nothing is saved or charged and the original clothing is restored when the menu closes. Turn off to use the fixed strip in Config.tattooStrip with no buttons.',
            live = true,
        }) or true,
        -- Character creation (and the admin session) also offers tattoos, but
        -- clothing there hides them. When on, choosing a tattoo there bares the
        -- clothing over its area for the preview (Head -> headwear, Torso/Arms/
        -- Back -> top, Legs -> legs, using the `parts` below). Preview only: the
        -- outfit that is saved is unchanged, and choosing an item in the menu for
        -- a bared slot dresses it again. Read each time a tattoo is chosen.
        previewInCreator = config and config.boolean(true, {
            label = 'Show tattoos through clothing in character creation',
            description = 'In character creation, picking a tattoo temporarily takes off the clothing covering that body area so the tattoo is visible. Preview only: the saved outfit is not changed. Turn off to leave clothing on.',
            live = true,
        }) or true,
        -- Parts (ids from `parts` below) already removed when the studio opens.
        -- The default matches what the studio always did before the buttons
        -- existed (top, legs and head cover off, shoes left on), so tattoos on
        -- the torso, arms and legs are visible straight away. Use {} to open
        -- fully dressed, or add 'shoes' to open fully bare.
        autoUndressOnOpen = config and config.list({ 'top', 'legs', 'headwear' }, config.string('top'), {
            label = 'Parts removed when the studio opens',
            description = 'Part ids from the parts list that are taken off when the tattoo studio opens: top, legs, shoes, headwear. Leave the list empty to open fully dressed. Players can still toggle every part with the buttons.',
            live = true,
        }) or { 'top', 'legs', 'headwear' },
        -- Each part is one button. `male` / `female` list the freemode
        -- components set to a bare drawable (id = GTA component id, d = drawable,
        -- t = texture) for that ped model; `props` lists the prop slots that are
        -- cleared (0 = hat, 1 = glasses, 2 = ear piece). 'top' covers the torso
        -- (jacket/shirt, undershirt, arms/gloves -- GTA component 3, 8 and 11),
        -- 'headwear' covers the mask (component 1), hat and glasses. The bare
        -- drawables are the stock freemode ones, which DLC clothing never
        -- renumbers; adjust per server if a clothing pack changes what looks bare.
        parts = (function()
            -- An empty untyped table is dropped by the config adopter, which would
            -- leave the part without its required `props` list, so slot lists are
            -- declared explicitly.
            local function slots(list)
                if not config then return list end
                return config.list(list, config.integer(0, { min = 0 }))
            end
            local parts = {
                {
                    id = 'top', label = 'Top',
                    male = { { id = 3, d = 15, t = 0 }, { id = 8, d = 15, t = 0 }, { id = 11, d = 15, t = 0 } },
                    female = { { id = 3, d = 15, t = 0 }, { id = 8, d = 15, t = 0 }, { id = 11, d = 15, t = 0 } },
                    props = slots({}),
                },
                {
                    id = 'legs', label = 'Legs',
                    male = { { id = 4, d = 21, t = 0 } },
                    female = { { id = 4, d = 15, t = 0 } },
                    props = slots({}),
                },
                {
                    id = 'shoes', label = 'Shoes',
                    male = { { id = 6, d = 34, t = 0 } },
                    female = { { id = 6, d = 35, t = 0 } },
                    props = slots({}),
                },
                {
                    id = 'headwear', label = 'Hat, mask and glasses',
                    male = { { id = 1, d = 0, t = 0 } },
                    female = { { id = 1, d = 0, t = 0 } },
                    props = slots({ 0, 1 }),
                },
            }
            if not config then return parts end
            local component = config.object({
                id = config.integer(0, { min = 0 }),
                d = config.integer(0, { min = 0 }),
                t = config.integer(0, { min = 0 }),
            })
            local part = config.object({
                id = config.string('top'),
                label = config.string('Top'),
                male = config.list({}, component),
                female = config.list({}, component),
                props = config.list({}, config.integer(0, { min = 0 })),
            })
            return config.list(parts, part, {
                label = 'Tattoo studio undress parts',
                description = 'One button per part. For each part, the male and female lists give the clothing component (id), bare drawable (d) and texture (t) used while previewing, and props lists the prop slots cleared (0 hat, 1 glasses, 2 ear piece). Only valid non-negative GTA component, drawable and texture ids; an out-of-range drawable is skipped. Never saved.',
                live = true,
            })
        end)(),
    },

    peds = {
        -- Off by default: servers with their own tattoo MLO or artist ped would
        -- otherwise get a second artist standing in the same spot. When on,
        -- every shop with service = 'tattoo' gets one (see below). Read while
        -- the player is moving about, so it can be flipped without a restart.
        enabled = config and config.boolean(false, {
            label = 'Tattoo artist peds',
            description = 'Spawns a frozen tattoo artist ped in each tattoo shop (client side, only while you are nearby). Targeting the artist with "Get tattooed" opens the tattoo studio. The artist is faded out while you are in the studio so they do not block the view. Leave off if your map or MLO already has its own artist. The decorative shop clerk for these shops is not spawned while this is on, to avoid two peds in one spot.',
            live = true,
        }) or false,
        -- Opacity (0 invisible .. 255 fully visible) of the artist while the
        -- studio menu is open. Local to the player in the studio.
        alpha = config and config.integer(0, {
            min = 0, max = 255,
            label = 'Artist opacity in the studio',
            description = 'How visible the tattoo artist ped is while you are in the studio menu: 0 is invisible, 255 is fully visible. Only you see the change.',
            live = true,
        }) or 0,
        -- Players within this many metres of the shop have the artist spawned;
        -- it is deleted again beyond it (plus a small margin).
        scopeRadius = config and config.number(40.0, {
            min = 5.0, max = 300.0,
            label = 'Artist spawn distance',
            description = 'Distance in metres at which the tattoo artist ped appears for you. It is removed again when you walk away.',
            live = true,
        }) or 40.0,
        -- Fallback model when a shop sets neither `tattooPed.model` nor `ped`.
        model = config and config.string('u_m_y_tattoo_01', {
            label = 'Default artist model',
            description = 'Ped model used for the tattoo artist when a shop does not set its own. The default shops already name u_m_y_tattoo_01.',
            live = true,
        }) or 'u_m_y_tattoo_01',
        -- Optional ambient scenario for the artist, e.g. 'WORLD_HUMAN_STAND_IMPATIENT'.
        -- nil leaves the ped idle.
        scenario = config and config.optional(nil, config.string('WORLD_HUMAN_STAND_IMPATIENT'), {
            label = 'Artist scenario',
            description = 'Optional GTA scenario the artist plays while standing there, for example WORLD_HUMAN_STAND_IMPATIENT. Leave unset for a plain idle ped.',
            live = true,
        }) or nil,
        -- Per shop, in Config.shops: `tattooPed = { model = '...', coords = vector4(...), scenario = '...' }`
        -- overrides the model (default: the shop's own `ped`), the position
        -- (default: the shop's `coords`) and the scenario; `tattooPed = false`
        -- gives that shop no artist. Keep the artist within a metre or two of
        -- the shop's `coords`: the server only opens a session for players near them.
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

-- Off (default): barbers and hairdressers both serve everyone, and the server
-- gives each player the menu matching their freemode model. On: a barber only
-- serves male freemode models and a hairdresser only female ones; the wrong
-- gender is told to try the other shop. Shop visits only -- admin sessions,
-- character creation and other services are unaffected. Read on every shop
-- visit, so changes apply to the next session without a restart.
Config.genderLockedSalons = config and config.boolean(false, {
    label = 'Gender-locked salons',
    description = 'When enabled, barbers only serve male characters and hairdressers only female characters, and anyone else is told to try the other shop. When disabled, both shops serve everyone and show the menu matching the character. Admin sessions and character creation are not affected. Applies to the next shop visit.',
    live = true,
}) or false

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

-- Ends a rotate drag whenever the mouse button release cannot be seen: the cursor
-- left the game window, focus was lost, or a move arrives with the button up.
-- Without it the camera keeps spinning until the player clicks again. Read each
-- time the menu opens.
Config.rotateDragGuard = config and config.boolean(true, {
    label = 'End rotate drag when the mouse is lost',
    description = 'Stops rotating the character when the cursor leaves the game window, the window loses focus, or the mouse button is released out of sight. Turn off to use the plain press/release drag.',
    live = true,
}) or true

-- How drag-to-rotate keeps working when the cursor reaches the screen edge.
-- 'pointer' (default) asks the browser for pointer lock on mouse down and turns the
-- character by the mouse movement deltas, so the cursor never reaches the edge and
-- NUI focus is never toggled (no cursor blink); if the lock is refused the drag
-- falls back to 'recenter'. 'controls' hides the cursor for the drag and reads
-- the mouse as a game control (it toggles NUI focus, which can flash the cursor);
-- 'recenter' moves the cursor back to the screen centre near an edge; 'plain'
-- captures nothing. Read each time the menu opens.
Config.rotateMode = config and config.enum('pointer', {
    options = { 'pointer', 'controls', 'recenter', 'plain' },
    label = 'Rotate drag mode',
    description = "How rotating the character with the mouse survives the cursor reaching the screen edge. pointer: the mouse is locked while you hold the button so rotation never stops at the screen edge (falls back to recentre if the lock is refused). controls: the cursor is hidden and the game reads the mouse (switches NUI focus, which can flash the cursor). recenter: the cursor is moved back to the centre near the edge. plain: no capture.",
    live = true,
}) or 'pointer'

-- Rotation speed for the pointer, recenter and plain modes (controls mode has its
-- own rotateControlsSensitivity). Multiplies the built-in 0.15 degrees per pixel.
Config.rotateSensitivity = config and config.number(1.0, {
    min = 0.1, max = 10.0,
    label = 'Rotate sensitivity',
    description = 'How fast the character turns per pixel of mouse movement while dragging to rotate (pointer, recenter and plain modes). 1.0 is the default; raise it to turn faster, lower it for finer control.',
    live = true,
}) or 1.0

-- Also lets the right mouse button rotate the character, in every rotateMode.
Config.rotateRightButton = config and config.boolean(true, {
    label = 'Right mouse button rotates',
    description = 'Holding the right mouse button over the character rotates it, like the left button. Turn off to rotate with the left button only.',
    live = true,
}) or true

-- Reverses the drag direction in every rotateMode (default: dragging right turns
-- the character clockwise, like grabbing its front).
Config.rotateInvert = config and config.boolean(false, {
    label = 'Invert rotate direction',
    description = 'Reverses which way the character turns when you drag the mouse left or right.',
    live = true,
}) or false

-- rotateMode = 'recenter' only. How close to a screen edge (fraction of the
-- screen) the cursor must get before it is moved back to the centre.
Config.rotateRecenterEdge = config and config.number(0.04, {
    min = 0.01, max = 0.3,
    label = 'Recentre distance from edge (recenter mode)',
    description = 'In recenter mode the cursor is only moved back to the screen centre once it is this close to an edge (0.04 = 4% of the screen).',
    live = true,
}) or 0.04

-- rotateMode = 'controls' only. Degrees turned per unit of mouse movement as the
-- game reports it (INPUT_LOOK_LR, -1..1 per frame). Raise it if turning feels slow.
Config.rotateControlsSensitivity = config and config.number(8.0, {
    min = 0.5, max = 60.0,
    label = 'Rotate sensitivity (controls mode)',
    description = 'Degrees the character turns per unit of mouse movement while rotating in controls mode. Higher turns faster.',
    live = true,
}) or 8.0

-- rotateMode = 'controls' only. Used when the game never reports the held mouse
-- button: the drag then lasts while the mouse keeps moving and ends this long
-- after it stops. If the button is reported, release ends the drag immediately.
Config.rotateControlsIdleSeconds = config and config.number(0.4, {
    min = 0.1, max = 5.0,
    label = 'Rotate idle end (controls mode)',
    description = 'If the game cannot see the held mouse button, a controls-mode rotate drag ends this many seconds after the mouse stops moving. Raise it if the drag ends while you hold still.',
    live = true,
}) or 0.4

-- rotateMode = 'controls' only. Hard stop for one drag, so a missed button
-- release can never leave the menu stuck without a cursor.
Config.rotateControlsMaxSeconds = config and config.number(30.0, {
    min = 2.0, max = 300.0,
    label = 'Longest single rotate drag (controls mode)',
    description = 'Safety limit in seconds: a rotate drag in controls mode always ends, and the cursor returns, after this long even if no button release was detected.',
    live = true,
}) or 30.0

-- Menu (NUI) options.
Config.ui = {
    -- Shows a small "Drag to rotate · Scroll to zoom" hint near the bottom of
    -- the screen when a clothing, barber, tattoo or creator menu opens. It does
    -- not take mouse input or cover any panel, and fades after the first rotate
    -- drag or wheel zoom, or after about 8 seconds. Read each time a menu opens.
    showControlsHint = config and config.boolean(true, {
        label = 'Show camera controls hint',
        description = 'Shows a short Drag to rotate / Scroll to zoom reminder when a clothing, barber, tattoo or creator menu opens. It fades after the first rotate or zoom, or after about 8 seconds. Turn off to never show it.',
        live = true,
    }) or true,
    -- Character creation (and admin sessions) open on the Style tab with Hair
    -- selected, so hair, hair colour, facial hair and eyebrows are visible at
    -- once instead of behind Style > Hair. Which of those parts are offered is
    -- still decided by Config.headOverlays. Off keeps the old start on Tops.
    creatorOpensOnHair = config and config.boolean(true, {
        label = 'Creator opens on hair and grooming',
        description = 'Character creation opens on the Style tab with Hair selected, so hair, hair colour, facial hair and eyebrows are shown straight away. Turn off to open on the first clothing tab instead; the hair options are then under Style > Hair. Barbers and clothing shops are unaffected.',
        live = true,
    }) or true,
}

-- Camera zoom presets the NUI can request via the `qbclothing:nui:camera`
-- callback. Offsets are relative to the ped's mid-spine bone (SKEL_Spine1,
-- roughly the belly, about 1.2m above the feet on a standing freemode ped) in
-- the ped's own forward-facing frame; client/camera.lua turns these into
-- world-space coords every frame so they track ped rotation during the live
-- orbit.
--   boneOffset.z : height the camera LOOKS AT, in metres above that spine bone
--                  (face ~ head centre, torso ~ chest, legs ~ thighs, shoes ~ feet).
--   camOffset.y  : distance from the ped; camOffset.z: camera height above the
--                  look-at point.
-- Tune boneOffset.z if a custom ped/scale frames a region too high or low.
--   track        : optional "head" or "feet". With Config.camera.frameToBones on, the
--                  look-at point is that bone (SKEL_Head / lowest of the SKEL_L/R_Foot
--                  bones) plus trackOffset (metres, up) instead of boneOffset.z, so
--                  the framing follows the real height of any ped model.
--   trackOffset  : metres above the tracked bone to look at.
Config.camera = {
    -- Frame the face and shoes zones on the ped's head and foot bones, and size
    -- the camera limits from them, instead of from the model bounding box. Fixes
    -- the face view stopping at the shoulders and the shoes view dropping under
    -- the map on female / differently sized peds. Turn off for the old
    -- spine-offset framing. Read while the camera runs.
    frameToBones = config and config.boolean(true, {
        label = 'Frame head and feet on their bones',
        description = "Centres the face and shoes camera views on the character's head and foot bones so they work for every ped model and height. Turn off to use the fixed offsets from the spine instead.",
        live = true,
    }) or true,
    -- The fitting-room camera is never lower than this many metres above the
    -- floor under the ped's feet, so the shoes view cannot go under the map.
    -- 0 turns the floor clamp off.
    minHeightAboveGround = config and config.number(0.15, {
        min = 0.0, max = 1.0,
        label = 'Minimum camera height above ground',
        description = 'Lowest the fitting-room camera may go above the floor, in metres, so the shoes view never ends up underneath the map. 0 disables the limit.',
        live = true,
    }) or 0.15,
    zones = {
        full  = { boneOffset = vector3(0.0, 0.0, 0.0),   camOffset = vector3(0.0, 2.2, 0.3),  fov = 45.0 },
        face  = { boneOffset = vector3(0.0, 0.0, 0.5),   camOffset = vector3(0.0, 0.65, 0.0), fov = 30.0, track = 'head', trackOffset = 0.04 },
        torso = { boneOffset = vector3(0.0, 0.0, 0.1),   camOffset = vector3(0.0, 1.3, 0.05), fov = 35.0 },
        legs  = { boneOffset = vector3(0.0, 0.0, -0.55), camOffset = vector3(0.0, 1.4, 0.05), fov = 35.0 },
        shoes = { boneOffset = vector3(0.0, 0.0, -1.05), camOffset = vector3(0.0, 1.0, 0.1),  fov = 35.0, track = 'feet', trackOffset = 0.12 },
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
    -- category never carries over to the next. When false (the default) the
    -- camera stays exactly where the player left it until they use the zone
    -- buttons at the top; the player already has full camera control, so a
    -- forced move on every tab click is more irritating than helpful. Read
    -- each time a category is chosen.
    resetOnCategoryChange = config and config.boolean(false, {
        label = 'Move camera when changing category',
        description = 'Moves the fitting-room camera to the framing for each clothing or tattoo category when it is selected, and clears any mouse-wheel zoom. Off by default so the camera stays where the player put it; the camera buttons at the top always work.',
        live = true,
    }) or false,
    -- Where the camera starts when a clothing, barber, tattoo or creator menu
    -- opens. 'front' places it in front of the ped, looking at the face, so
    -- the player sees the character face-on. 'current' keeps the older
    -- behaviour of starting at an orbit angle of 0 relative to the ped's
    -- heading, which looks side-on or from behind for most headings. The
    -- player can drag to rotate either way. Read each time a menu opens.
    initialView = config and config.enum('front', {
        label = 'Starting camera view',
        description = 'Where the camera starts when a clothing, barber, tattoo or creator menu opens. Front puts it in front of the character, face-on; Previous keeps the old starting angle, which is often side-on.',
        options = {
            { value = 'front', label = 'Front (face-on)' },
            { value = 'current', label = 'Previous behaviour' },
        },
        live = true,
    }) or 'front',
    -- Which entry of `zones` the camera starts framing. 'full' shows the whole
    -- body (the widest preset, so the player sees the ped they are about to
    -- dress and can zoom in); use 'face' or 'torso' for a closer start. An
    -- unknown name falls back to 'full'. Read each time a menu opens.
    initialPreset = config and config.string('full', {
        label = 'Starting camera preset',
        description = 'Name of the camera preset used when a menu opens: full, face, torso, legs or shoes. Full shows the whole body face-on. An unknown name uses full.',
        live = true,
    }) or 'full',
    -- Orbit rotation and zoom-transition speeds, tuned for the "smooth, not a
    -- jump-cut" illenium-style feel called for by UX.
    orbitDegPerSec = 90.0,
    transitionMs = 350,
}

-- Quick clothing toggles: `/c vest`, `/c pants`, ... take ONE item off and
-- a second use puts back exactly what was worn (drawable, texture, palette).
-- Everything is local to the player's ped: nothing is sent to the server or
-- saved, so the saved outfit stays the "put back" state. Opening a fitting-room
-- menu puts everything back first. If the player changes an item themselves
-- (menu, outfit, another script) after taking it off, the remembered value is
-- stale and is dropped instead of being restored over their change.
-- The command name is registered when the resource starts; the other options
-- are read each time the command is used.
--
--   enabled      : master switch for the whole feature (no command, no suggestion).
--   command      : chat command name.
--   cooldownMs   : minimum time between two uses; 0 disables the cooldown.
--   allowDead / allowCuffed / allowInVehicle : whether the command works in that state.
--   animations   : short clothing animation per part (each part's animDict/animClip/animMs).
--                  Never played in a vehicle (animationsInVehicle) or when a part has no animDict.
--   chatSuggestion : register the /c chat suggestion listing the valid parts.
--   visor        : { male = { [hatDrawable] = otherDrawable }, female = ... } pairs of
--                  hat/helmet drawables that are the same helmet with the visor up/down.
--                  `/c visor` swaps between the two (texture kept, either direction works).
--                  GTA offers no way to detect visor variants, so empty by default: the player
--                  then sees "no visor variant". Fill in for the helmets of your clothing pack.
--   parts        : id (also the argument), aliases (other accepted arguments), label,
--                  male/female = freemode components set to a "nothing" drawable
--                  (id = GTA component, d = drawable, t = texture), props = prop slots cleared
--                  (0 hat, 1 glasses, 2 ears, 6 watch, 7 bracelet). The defaults are the stock
--                  freemode "bare" drawables, like Config.tattoo.undress.parts. `visor` marks the
--                  part handled through Config.quickToggle.visor instead. `shirt` includes the
--                  undershirt and arms so the torso looks right. Only valid ids; an
--                  out-of-range drawable is skipped. `reset` / `all` (and `/c` with
--                  `resetWords`) put everything back.
Config.quickToggle = {
    enabled = config and config.boolean(true, {
        label = 'Quick clothing toggles (/c <part>)',
        description = 'Adds a chat command (default /c) with a part argument (vest, shirt, pants, shoes, hat, mask, visor, glasses, ...) that takes that clothing item off and, on a second use, puts it back. Temporary: nothing is saved. Turn off to remove the command and its chat suggestion (applies on the next resource start).',
    }) or true,
    command = config and config.string('c', {
        label = 'Quick toggle command name',
        description = 'Chat command name without the slash. Change it if another resource already uses /c. Applies on the next resource start.',
    }) or 'c',
    chatSuggestion = config and config.boolean(true, {
        label = 'Quick toggle chat suggestion',
        description = 'Shows the command and its valid parts in the chat suggestions.',
    }) or true,
    cooldownMs = config and config.integer(1500, {
        min = 0, max = 60000,
        label = 'Quick toggle cooldown (ms)',
        description = 'Minimum time between two uses of the command by one player. 0 disables the cooldown.',
        live = true,
    }) or 1500,
    allowDead = config and config.boolean(false, {
        label = 'Quick toggles while dead',
        description = 'Allow the command while the player is dead or downed.',
        live = true,
    }) or false,
    allowCuffed = config and config.boolean(false, {
        label = 'Quick toggles while cuffed',
        description = 'Allow the command while handcuffed (needs kora_police; ignored if it is not running).',
        live = true,
    }) or false,
    allowInVehicle = config and config.boolean(true, {
        label = 'Quick toggles in a vehicle',
        description = 'Allow the command while sitting in a vehicle.',
        live = true,
    }) or true,
    animations = config and config.boolean(true, {
        label = 'Quick toggle animations',
        description = 'Plays a short clothing animation when an item is taken off or put back. Turn off for instant changes.',
        live = true,
    }) or true,
    animationsInVehicle = config and config.boolean(false, {
        label = 'Quick toggle animations in a vehicle',
        description = 'Also play the animation while in a vehicle. Off by default: the change is instant there.',
        live = true,
    }) or false,
    resetWords = config and config.list({ 'reset', 'all' }, config.string('reset'), {
        label = 'Quick toggle reset arguments',
        description = 'Arguments that put every removed item back on.',
        live = true,
    }) or { 'reset', 'all' },
    visor = {
        male = {},
        female = {},
    },
    parts = (function()
        local function ids(list)
            if not config then return list end
            return config.list(list, config.integer(0, { min = 0 }))
        end
        local function words(list)
            if not config then return list end
            return config.list(list, config.string('x'))
        end
        local function comps(list)
            if not config then return list end
            return config.list(list, config.object({
                id = config.integer(0, { min = 0 }),
                d = config.integer(0, { min = 0 }),
                t = config.integer(0, { min = 0 }),
            }))
        end
        local head = { animDict = 'clothingtie', animClip = 'try_tie_neutral_a', animMs = 1200 }
        local body = { animDict = 'clothingshirt', animClip = 'try_shirt_positive_a', animMs = 1500 }
        local function part(def, anim)
            def.aliases = words(def.aliases or {})
            def.props = ids(def.props or {})
            -- Typed lists: the config adopter drops empty untyped tables, which would
            -- leave prop-only parts (hat, glasses, ...) without their male/female list.
            def.male = comps(def.male or {})
            def.female = comps(def.female or {})
            def.visor = def.visor == true
            def.animDict, def.animClip, def.animMs = anim.animDict, anim.animClip, anim.animMs
            return def
        end
        local function shirtSet() return { { id = 3, d = 15, t = 0 }, { id = 8, d = 15, t = 0 }, { id = 11, d = 15, t = 0 } } end
        local parts = {
            part({ id = 'vest', label = 'Vest', aliases = { 'kevlar', 'armor', 'armour' }, male = { { id = 9, d = 0, t = 0 } }, female = { { id = 9, d = 0, t = 0 } } }, body),
            part({ id = 'shirt', label = 'Shirt', aliases = { 'top', 'jacket', 'torso' }, male = shirtSet(), female = shirtSet() }, body),
            part({ id = 'pants', label = 'Pants', aliases = { 'legs', 'trousers' }, male = { { id = 4, d = 21, t = 0 } }, female = { { id = 4, d = 15, t = 0 } } }, body),
            part({ id = 'shoes', label = 'Shoes', aliases = { 'feet', 'boots' }, male = { { id = 6, d = 34, t = 0 } }, female = { { id = 6, d = 35, t = 0 } } }, body),
            part({ id = 'hat', label = 'Hat', aliases = { 'helmet', 'cap' }, props = { 0 } }, head),
            part({ id = 'mask', label = 'Mask', male = { { id = 1, d = 0, t = 0 } }, female = { { id = 1, d = 0, t = 0 } } }, head),
            part({ id = 'visor', label = 'Visor', visor = true, props = { 0 } }, head),
            part({ id = 'glasses', label = 'Glasses', aliases = { 'glass', 'shades' }, props = { 1 } }, head),
            part({ id = 'bag', label = 'Bag', aliases = { 'backpack' }, male = { { id = 5, d = 0, t = 0 } }, female = { { id = 5, d = 0, t = 0 } } }, body),
            part({ id = 'chain', label = 'Neck item', aliases = { 'neck', 'necklace', 'tie' }, male = { { id = 7, d = 0, t = 0 } }, female = { { id = 7, d = 0, t = 0 } } }, head),
            part({ id = 'ears', label = 'Earrings', aliases = { 'earrings', 'ear' }, props = { 2 } }, head),
            part({ id = 'watch', label = 'Watch', props = { 6 } }, body),
            part({ id = 'bracelet', label = 'Bracelet', props = { 7 } }, body),
        }
        if not config then return parts end
        local component = config.object({
            id = config.integer(0, { min = 0 }),
            d = config.integer(0, { min = 0 }),
            t = config.integer(0, { min = 0 }),
        })
        local schema = config.object({
            id = config.string('shirt'),
            label = config.string('Shirt'),
            aliases = config.list({}, config.string('x')),
            male = config.list({}, component),
            female = config.list({}, component),
            props = config.list({}, config.integer(0, { min = 0 })),
            visor = config.boolean(false),
            animDict = config.string(''),
            animClip = config.string(''),
            animMs = config.integer(1500, { min = 0, max = 10000 }),
        })
        return config.list(parts, schema, {
            label = 'Quick toggle parts',
            description = 'One entry per /c argument: id, aliases, and the freemode components (id/drawable/texture "nothing" values per gender) and prop slots it removes. animDict/animClip/animMs set the animation (leave animDict empty for none). Only valid non-negative ids; an out-of-range drawable is skipped. Never saved.',
            live = true,
        })
    end)(),
}

-- Registers this resource-owned configuration with kora_lib without changing its public Config table.
if Kora and Kora.config and Kora.config.adopt then
    local tattooStripItem = Kora.config.object({
        d = Kora.config.integer(0, { min = 0 }),
        t = Kora.config.integer(0, { min = 0 }),
    })
    Config.tattooStrip.male = Kora.config.map(Config.tattooStrip.male, tattooStripItem, {
        keyType = 'integer',
        live = true,
        label = 'Male tattoo preview clothing',
        description = 'Maps GTA clothing component IDs to temporary drawable (d) and texture (t) variations used while a male freemode character previews tattoos. Add only valid non-negative component, drawable, and texture IDs; the original outfit is restored when the tattoo session closes.',
    })
    Config.tattooStrip.female = Kora.config.map(Config.tattooStrip.female, tattooStripItem, {
        keyType = 'integer',
        live = true,
        label = 'Female tattoo preview clothing',
        description = 'Maps GTA clothing component IDs to temporary drawable (d) and texture (t) variations used while a female freemode character previews tattoos. Add only valid non-negative component, drawable, and texture IDs; the original outfit is restored when the tattoo session closes.',
    })
    local visorPair = Kora.config.integer(0, { min = 0 })
    for _, gender in ipairs({ 'male', 'female' }) do
        Config.quickToggle.visor[gender] = Kora.config.map(Config.quickToggle.visor[gender], visorPair, {
            keyType = 'integer',
            live = true,
            label = ('Quick toggle visor pairs (%s)'):format(gender),
            description = 'Maps a hat/helmet drawable to the drawable of the same helmet with the visor in the other position. /c visor swaps between the two (works in both directions if you list both). Empty means no helmet has a visor variant.',
        })
    end
    Config = Kora.config.adopt(Config)
end

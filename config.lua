-- Own config, self-contained -- matches kora_multichar's convention of owning
-- its data rather than reading kora_core's shared registries. Named `Config`,
-- not a `Kora`-prefixed global -- kora_lib's `@kora_lib/init.lua` already owns the
-- global `Kora` as a live cross-resource proxy in this codebase.

Config = {}

-- Descriptors make a setting editable in kora_lib's config workspace and are
-- resolved back to plain values by Kora.config.adopt at the end of this file.
-- Without kora_lib's config module the plain defaults after `or` are used.
local config = Kora and Kora.config

-- Boolean setting: a config-workspace descriptor when kora_lib's config module is
-- loaded, otherwise the plain default. Avoid `config.boolean(...) or true`: with
-- the module missing it turns a default edited to false back into true.
local function boolean(default, options)
    if config then return config.boolean(default, options) end
    return default
end

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
--   suppressClientPopulation : also stop this client from spawning ambient peds
--                       and vehicles (population budgets set to 0, nearby ones
--                       cleared) from the moment a new character's creation
--                       starts until the fitting room closes. The routing
--                       bucket only removes population the server owns; a
--                       client-owned crowd and the world the player spawned into
--                       a moment earlier are still around without this. Done
--                       once on enter and once on leave, nothing runs per frame.
Config.bucket = {
    base = 1000000,
    disablePopulation = boolean(true, {
        label = 'Disable ambient population in the first-character fitting room',
        description = 'When enabled, ambient peds and vehicles (traffic, jet skis, pedestrians) are switched off inside the private routing bucket used for the one-time first-character fitting room, so they do not wander through the creation scene. Only that personal bucket is affected, never the normal world, and shop, barber and wardrobe sessions are unchanged. Applies the next time a first-character fitting room opens.',
        live = true,
    }),
    suppressClientPopulation = boolean(true, {
        label = 'Hide ambient peds and vehicles during character creation',
        description = 'While a new character is being created, this player stops seeing ambient pedestrians and traffic: population budgets are set to zero and nearby peds and vehicles are cleared, then the budgets are restored when the fitting room closes. Only the creating player is affected. Applies the next time a character is created.',
        live = true,
    }),
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

-- Heritage: the mother and father a character takes after (head blend parents), how
-- much the face and the skin lean towards each, and the face style / skin tone as
-- the "auto" parents. Creation-only, like skin tone, and saved with the character.
-- Characters saved before this existed keep their look (auto parents). Read each
-- time a menu opens and again on every change and confirm.
Config.heritage = {
    creator = boolean(true, {
        label = 'Mother and father in character creation',
        description = 'Shows a Heritage panel with the Face item while creating a character: pick a mother and a father for the face shape and the skin, and how much the face and skin resemble each one. Turn off to hide it; characters then keep the face style and skin tone they had.',
        live = true,
    }),
}

-- Which head overlays players can edit, per kind of session: `creator` is
-- character creation (and admin sessions), `barber` is the barber/hairdresser.
-- A category set to false is hidden in the menu and ignored by the client and
-- the server. Skin tone stays creation-only and is not configurable here.
-- The make-up overlays (makeup, blush, lipstick) appear next to hair, facial hair and
-- the rest in the Hair item. They take their colour from the make-up palette, so they
-- have no followHairColor option.
Config.headOverlays = {
    makeup = {
        creator = boolean(true, {
            label = 'Make-up in character creation',
            description = 'Lets players choose a make-up style, opacity and colour while creating a character. Turn off to hide make-up options from creation.',
            live = true,
        }),
        barber = boolean(false, {
            label = 'Make-up at the barber',
            description = 'Lets players change make-up style, opacity and colour at barbers and hairdressers, charged at the hair price. Off by default.',
            live = true,
        }),
    },
    blush = {
        creator = boolean(true, {
            label = 'Blush in character creation',
            description = 'Lets players choose a blush style, opacity and colour while creating a character. Turn off to hide blush options from creation.',
            live = true,
        }),
        barber = boolean(false, {
            label = 'Blush at the barber',
            description = 'Lets players change blush style, opacity and colour at barbers and hairdressers, charged at the hair price. Off by default.',
            live = true,
        }),
    },
    lipstick = {
        creator = boolean(true, {
            label = 'Lipstick in character creation',
            description = 'Lets players choose a lipstick style, opacity and colour while creating a character. Turn off to hide lipstick options from creation.',
            live = true,
        }),
        barber = boolean(false, {
            label = 'Lipstick at the barber',
            description = 'Lets players change lipstick style, opacity and colour at barbers and hairdressers, charged at the hair price. Off by default.',
            live = true,
        }),
    },
    eyebrows = {
        creator = boolean(true, {
            label = 'Eyebrows in character creation',
            description = 'Lets players choose eyebrow style, opacity and colour while creating a character. Turn off to hide eyebrow options from creation.',
            live = true,
        }),
        barber = boolean(true, {
            label = 'Eyebrows at the barber',
            description = 'Lets players change eyebrow style, opacity and colour at barbers and hairdressers, charged at the hair price. Turn off to hide eyebrow options there.',
            live = true,
        }),
        -- Off (default): eyebrows have their own colour palette, independent of the
        -- hair colour. Characters saved before that palette existed have no eyebrow
        -- colour of their own and keep matching their hair until a colour is picked
        -- (or a colour is picked). On: the eyebrow palette is hidden and
        -- eyebrows always take the primary hair colour, the old behaviour.
        followHairColor = boolean(false, {
            label = 'Eyebrows follow hair colour',
            description = 'Off (default): players pick an eyebrow colour of their own, separate from hair colour. On: no eyebrow colour palette is shown and eyebrows always use the primary hair colour. Applies to character creation and barbers.',
            live = true,
        }),
    },
    facialHair = {
        creator = boolean(true, {
            label = 'Facial hair in character creation',
            description = 'Lets players choose facial hair style, opacity and colour while creating a character. Turn off to hide facial hair options from creation.',
            live = true,
        }),
        barber = boolean(true, {
            label = 'Facial hair at the barber',
            description = 'Lets players change facial hair style, opacity and colour at barbers and hairdressers, charged at the hair price. Turn off to hide facial hair options there.',
            live = true,
        }),
        -- The menu has no "match hair colour" button; this is the server-side
        -- version of it. On: no facial hair palette is shown and facial hair
        -- always takes the primary hair colour.
        followHairColor = boolean(false, {
            label = 'Facial hair follows hair color',
            description = 'Off (default): players pick a facial hair color of their own. On: no facial hair color palette is shown and facial hair always uses the primary hair color. Applies to character creation and barbers.',
            live = true,
        }),
    },
    chestHair = {
        creator = boolean(true, {
            label = 'Chest hair in character creation',
            description = 'Lets players choose chest hair style, opacity and colour while creating a character. Turn off to hide chest hair options from creation.',
            live = true,
        }),
        barber = boolean(true, {
            label = 'Chest hair at the barber',
            description = 'Lets players change chest hair style, opacity and colour at barbers and hairdressers, charged at the hair price. Turn off to hide chest hair options there.',
            live = true,
        }),
        followHairColor = boolean(false, {
            label = 'Chest hair follows hair color',
            description = 'Off (default): players pick a chest hair color of their own. On: no chest hair color palette is shown and chest hair always uses the primary hair color. Applies to character creation and barbers.',
            live = true,
        }),
    },
}

-- Login colour re-assert. The saved skin is applied as soon as the character
-- loads, but kora_multichar's spawn (resurrect, teleport, fade-in) can run
-- afterwards and reset the ped's hair tint and overlay colours to defaults;
-- opening any menu fixed it because that re-applies the colours. When enabled,
-- the saved hair colour, highlight and overlay colours (eyebrows, facial hair)
-- are applied again at each delay (milliseconds after the first apply). Ignored
-- if the player opens a fitting room or the model changes. Turn off to apply
-- the skin once only.
Config.loginColourReapply = {
    enabled = boolean(true, {
        label = 'Re-apply hair colour after login',
        description = 'Re-applies the saved hair colour, highlight and eyebrow/facial hair colours shortly after login, because the spawn sequence can reset them to default. Turn off to apply the saved look only once.',
        live = true,
    }),
    delays = { 750, 3000 },
}

-- Outfit a brand-new character starts in. A new character never inherits the
-- clothes of the character the player used before: the ped is reset to this
-- outfit when the character is created (before the first spawn) and the
-- character creation fitting room opens on it. Every component not listed is
-- reset to drawable 0, texture 0; props not listed are removed. Component and
-- prop ids follow GTA's (3 torso, 4 legs, 6 shoes, 8 undershirt, 11 top ...).
-- These are base-game freemode drawables; adjust per gender if a clothing pack
-- on your server shifts what looks sensible. Turn `enabled` off to keep the
-- previous behaviour (the ped's current clothes are carried over). The face,
-- skin tone, hair colour and head overlays (beard, eyebrows, chest hair) start
-- on their defaults (skin tone 0, no overlays) and no tattoos are applied.
Config.starterOutfit = {
    enabled = boolean(true, {
        label = 'New characters start in a starter outfit',
        description = 'On (default): a newly created character is reset to the starter outfit below before spawning and before the character creation menu opens, so it never inherits the previous character\'s clothes. Off: the ped keeps whatever it was wearing.',
        live = true,
    }),
    male = {
        components = {
            [3]  = { d = 0,  t = 0 }, -- torso
            [4]  = { d = 0,  t = 0 }, -- legs
            [6]  = { d = 1,  t = 0 }, -- shoes
            [8]  = { d = 15, t = 0 }, -- undershirt: none
            [11] = { d = 0,  t = 0 }, -- top: plain t-shirt
        },
        props = {},
    },
    female = {
        components = {
            [3]  = { d = 0,  t = 0 },
            [4]  = { d = 0,  t = 0 },
            [6]  = { d = 1,  t = 0 },
            [8]  = { d = 15, t = 0 },
            [11] = { d = 0,  t = 0 },
        },
        props = {},
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
        points = { register = vector4(125.35, -223.62, 54.56, 248.79), racks = vector4(121.63, -224.23, 54.56, 152.18) },
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
        points = { register = vector4(75.80, -1392.88, 29.38, 90.89), racks = vector4(78.76, -1397.40, 29.38, 267.65) },
        zone = { size = vector3(2.2, 1.8, 2.2), rotation = 0.0 },
        blip = { enabled = true, sprite = 73, color = 3, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Suburban' },
    },
    {
        service = 'clothing', free = false, label = 'Ponsonbys',
        ped = 'a_m_y_business_03',
        coords = vector4(-708.61, -152.85, 36.42, 30.0),
        points = { register = vector4(-710.34, -152.69, 37.42, 298.30), racks = vector4(-708.64, -160.39, 37.42, 209.55) },
        zone = { size = vector3(2.2, 1.8, 2.2), rotation = 30.0 },
        blip = { enabled = true, sprite = 73, color = 27, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Ponsonbys' },
    },
    {
        service = 'clothing', free = false, label = 'Ponsonbys',
        ped = 'a_f_y_business_01',
        coords = vector4(-167.79, -299.05, 38.73, 250.0),
        points = { register = vector4(-163.47, -303.67, 39.73, 70.19), racks = vector4(-158.79, -296.45, 39.73, 341.35) },
        zone = { size = vector3(2.2, 1.8, 2.2), rotation = 250.0 },
        blip = { enabled = true, sprite = 73, color = 27, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Ponsonbys' },
    },
    {
        service = 'clothing', free = false, label = 'Binco',
        ped = 'a_m_y_business_02',
        coords = vector4(-1193.44, -772.12, 16.32, 130.0),
        points = { register = vector4(-1192.75, -768.44, 17.32, 36.34), racks = vector4(-1189.30, -769.79, 17.33, 245.16) },
        zone = { size = vector3(2.2, 1.8, 2.2), rotation = 130.0 },
        blip = { enabled = true, sprite = 73, color = 5, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Binco' },
    },
    {
        service = 'clothing', free = false, label = 'Binco',
        ped = 'a_f_y_hipster_02',
        coords = vector4(-827.86, -1073.75, 9.33, 130.0),
        points = { register = vector4(-822.16, -1073.86, 11.33, 29.02), racks = vector4(-824.60, -1078.85, 11.33, 207.89) },
        zone = { size = vector3(2.2, 1.8, 2.2), rotation = 130.0 },
        blip = { enabled = true, sprite = 73, color = 5, scale = 0.8, shortRange = true, category = 'Clothing', name = 'Binco' },
    },
    {
        service = 'tattoo', free = false, label = 'Tattoo Artist',
        ped = 'u_m_y_tattoo_01',
        coords = vector4(1321.61, -1653.76, 52.28, 354.98),
        zone = {
            points = {
                vector3(1322.69, -1652.85, 52.28),
                vector3(1320.70, -1652.68, 52.28),
                vector3(1320.53, -1654.67, 52.28),
                vector3(1322.52, -1654.84, 52.28),
            },
            minZ = 51.18, maxZ = 53.38,
        },
        blip = { enabled = true, sprite = 75, color = 1, scale = 0.8, shortRange = true, category = 'Tattoo' },
    },
    {
        service = 'tattoo', free = false, label = 'Tattoo Artist',
        ped = 'u_m_y_tattoo_01',
        coords = vector4(324.22, 180.12, 103.59, 102.14),
        zone = {
            points = {
                vector3(323.03, 180.89, 103.59),
                vector3(323.45, 178.93, 103.59),
                vector3(325.41, 179.35, 103.59),
                vector3(324.99, 181.31, 103.59),
            },
            minZ = 102.49, maxZ = 104.69,
        },
        blip = { enabled = true, sprite = 75, color = 1, scale = 0.8, shortRange = true, category = 'Tattoo' },
    },
    {
        service = 'tattoo', free = false, label = 'Tattoo Artist',
        ped = 'u_m_y_tattoo_01',
        coords = vector4(1865.25, 3747.23, 33.03, 45.15),
        zone = {
            points = {
                vector3(1865.25, 3748.64, 33.03),
                vector3(1863.84, 3747.23, 33.03),
                vector3(1865.25, 3745.82, 33.03),
                vector3(1866.66, 3747.23, 33.03),
            },
            minZ = 31.93, maxZ = 34.13,
        },
        blip = { enabled = true, sprite = 75, color = 1, scale = 0.8, shortRange = true, category = 'Tattoo' },
    },
    {
        service = 'tattoo', free = false, label = 'Tattoo Artist',
        ped = 'u_m_y_tattoo_01',
        coords = vector4(-295.18, 6200.49, 31.49, 256.39),
        zone = {
            points = {
                vector3(-294.44, 6199.28, 31.49),
                vector3(-293.97, 6201.23, 31.49),
                vector3(-295.92, 6201.70, 31.49),
                vector3(-296.39, 6199.75, 31.49),
            },
            minZ = 30.39, maxZ = 32.59,
        },
        blip = { enabled = true, sprite = 75, color = 1, scale = 0.8, shortRange = true, category = 'Tattoo' },
    },
    {
        service = 'tattoo', free = false, label = 'Tattoo Artist',
        ped = 'u_m_y_tattoo_01',
        coords = vector4(-3169.57, 1077.46, 20.83, 200.35),
        zone = {
            points = {
                vector3(-3170.16, 1076.17, 20.83),
                vector3(-3168.28, 1076.87, 20.83),
                vector3(-3168.98, 1078.75, 20.83),
                vector3(-3170.86, 1078.05, 20.83),
            },
            minZ = 19.73, maxZ = 21.93,
        },
        blip = { enabled = true, sprite = 75, color = 1, scale = 0.8, shortRange = true, category = 'Tattoo' },
    },
    {
        service = 'tattoo', free = false, label = 'Tattoo Artist',
        ped = 'u_m_y_tattoo_01',
        coords = vector4(-1155.34, -1426.97, 4.95, 337.35),
        zone = {
            points = {
                vector3(-1154.03, -1426.43, 4.95),
                vector3(-1155.88, -1425.66, 4.95),
                vector3(-1156.65, -1427.51, 4.95),
                vector3(-1154.80, -1428.28, 4.95),
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
-- `peds`    : a tattoo artist standing in each tattoo shop. Targeting the artist
-- ("Get tattooed") opens the studio; while the artist is there the shop's own
-- zone (its sprite and "Open ..." prompt) is taken down, and it comes back
-- whenever there is no artist. While the studio is open the artist is faded
-- out locally so they do not block the view.
Config.tattoo = {
    -- Duplicate button in the studio list. Off keeps one instance per tattoo
    -- (extra instances are dropped server-side). Read each time a skin is
    -- sanitised or the studio opens.
    allowStacking = boolean(true, {
        label = 'Allow stacking tattoos',
        description = 'Lets players apply the same tattoo more than once (a copy button appears on applied tattoos) so it renders darker. Turn off to allow one instance of each tattoo; extra instances in saved skins are dropped.',
        live = true,
    }),
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
        enabled = boolean(true, {
            label = 'Tattoo studio undress buttons',
            description = 'Shows clothing buttons (top, legs, shoes, headwear, undress all) in the tattoo studio so players can see tattoos under their clothes. Preview only: nothing is saved or charged and the original clothing is restored when the menu closes. Turn off to use the fixed strip in Config.tattooStrip with no buttons.',
            live = true,
        }),
        -- Character creation (and the admin session) also offers tattoos, but
        -- clothing there hides them. When on, choosing a tattoo there bares the
        -- clothing over its area for the preview (Head -> headwear, Torso/Arms/
        -- Back -> top, Legs -> legs, using the `parts` below). Preview only: the
        -- outfit that is saved is unchanged, and choosing an item in the menu for
        -- a bared slot dresses it again. Read each time a tattoo is chosen.
        previewInCreator = boolean(true, {
            label = 'Show tattoos through clothing in character creation',
            description = 'In character creation, picking a tattoo temporarily takes off the clothing covering that body area so the tattoo is visible. Preview only: the saved outfit is not changed. Turn off to leave clothing on.',
            live = true,
        }),
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
        -- On by default, like the shop clerks elsewhere (kora_inventory's
        -- Config.ShopClerks, Ammu-Nation): every shop with service = 'tattoo'
        -- gets one (see below). Turn off on a map or MLO that already has its own
        -- artist. Applied live: the artists are rebuilt when this changes.
        enabled = boolean(true, {
            label = 'Tattoo artist peds',
            description = 'Spawns a frozen tattoo artist ped in each tattoo shop (client side, only while you are nearby). Targeting the artist with "Get tattooed" opens the tattoo studio, and the shop zone prompt is hidden while the artist is there. The artist is faded out while you are in the studio so they do not block the view. Turn off if your map or MLO already has its own artist; the shop zone is then used as before. The decorative shop clerk for these shops is not spawned while this is on, to avoid two peds in one spot.',
            live = true,
        }),
        -- Opacity (0 invisible .. 255 fully visible) of the artist while the
        -- studio menu is open. Local to the player in the studio.
        alpha = config and config.integer(0, {
            min = 0, max = 255,
            label = 'Artist opacity in the studio',
            description = 'How visible the tattoo artist ped is while you are in the studio menu: 0 is invisible, 255 is fully visible. Only you see the change.',
            live = true,
        }) or 0,
        -- Players within this many metres of the shop have the artist spawned;
        -- it is deleted again when they leave (a kora_lib zone, no polling).
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
        -- Ambient scenario the artist plays. nil or '' leaves the ped idle. Pick
        -- one without a hand prop (clipboard, phone, coffee): fading only
        -- reaches the ped, so a prop would stay floating in the studio view.
        scenario = config and config.optional('WORLD_HUMAN_STAND_IMPATIENT', config.string('WORLD_HUMAN_STAND_IMPATIENT'), {
            label = 'Artist scenario',
            description = 'GTA scenario the artist plays while standing there. Default WORLD_HUMAN_STAND_IMPATIENT. Leave unset for a plain idle ped. Avoid scenarios with a hand prop (clipboard, phone): the prop is not faded with the artist in the studio.',
            live = true,
        }) or 'WORLD_HUMAN_STAND_IMPATIENT',
        -- Per shop, in Config.shops: `tattooPed = { model = '...', coords = vector4(...), scenario = '...' }`
        -- overrides the model (default: the shop's own `ped`), the position
        -- (default: the shop's `coords`) and the scenario; `tattooPed = false`
        -- gives that shop no artist. `coords` use the same height as the shop's:
        -- where a standing player is (/coords or GetEntityCoords, about 1.0 above
        -- the floor); the artist is stood 1.0 below that, on the floor. Keep the
        -- artist within a metre or two of the shop's zone: the server only opens
        -- a session for players near it.
    },
}

Config.interactDistance = 2.0

-- Clothing shops with a `points = { register, racks }` entry (Config.shops) are
-- opened from a sphere of Config.clothingPointRadius around each of those two
-- points, in place of the shop's own zone, so every branch has the same two
-- easy-to-find spots and several players can spread out. Shops without
-- `points`, and barbers/tattoo/wardrobes, are unaffected.
Config.clothingShopPoints = boolean(true, {
    label = 'Clothing shop register/rack points',
    description = 'Opens clothing shops from a wide area around the register and the clothing racks instead of the small per-shop zone. Turn off to use each shop zone as before. Applies after the resource restarts.',
})

Config.clothingPointRadius = config and config.number(5.0, {
    min = 1.0, max = 15.0,
    label = 'Clothing shop point radius',
    description = 'Radius in metres around each clothing shop register and rack point in which the shop can be opened. Only used while Clothing shop register/rack points is on. Applies after the resource restarts.',
}) or 5.0

-- Hides the minimap while any clothing menu (shop, barber, tattoo, creator,
-- wardrobe) is open and restores it afterwards. Only used when kora_hud is not
-- running; kora_hud hides the radar itself.
Config.hideRadarInMenu = boolean(true, {
    label = 'Hide radar in menus',
    description = 'Hides the minimap while a clothing, barber, tattoo or character creation menu is open, then shows it again. Only applies when kora_hud is not running, because kora_hud already hides the radar itself.',
    live = true,
})

-- Off (default): barbers and hairdressers both serve everyone, and the server
-- gives each player the menu matching their freemode model. On: a barber only
-- serves male freemode models and a hairdresser only female ones; the wrong
-- gender is told to try the other shop. Shop visits only -- admin sessions,
-- character creation and other services are unaffected. Read on every shop
-- visit, so changes apply to the next session without a restart.
Config.genderLockedSalons = boolean(false, {
    label = 'Gender-locked salons',
    description = 'When enabled, barbers only serve male characters and hairdressers only female characters, and anyone else is told to try the other shop. When disabled, both shops serve everyone and show the menu matching the character. Admin sessions and character creation are not affected. Applies to the next shop visit.',
    live = true,
})

-- How players open a shop. 'target' uses a kora_target zone option; 'textui'
-- shows "[E] Open <shop>" through kora_lib's TextUI while inside the shop zone
-- and opens on E. Read when the resource starts. Default 'textui' since
-- suggestion thread 1565520418167717949 (target zones were hard to find).
Config.interactionMode = config and config.enum('textui', {
    label = 'Shop interaction',
    description = 'Chooses how players open a shop. Target Zone uses the kora_target prompt; Text Prompt shows an [E] Open message while standing inside the shop area. Changes apply after the resource restarts.',
    options = {
        { value = 'target', label = 'Target Zone' },
        { value = 'textui', label = 'Text Prompt' },
    },
}) or 'textui'

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
Config.rotatePointerLock = boolean(true, {
    label = 'Capture mouse while rotating',
    description = 'Locks the mouse while you hold click to rotate the character in clothing, barber, tattoo and creation menus, so rotation continues without lifting the button. Turn off to use a plain drag.',
    live = true,
})

-- Ends a rotate drag whenever the mouse button release cannot be seen: the cursor
-- left the game window, focus was lost, or a move arrives with the button up.
-- Without it the camera keeps spinning until the player clicks again. Read each
-- time the menu opens.
Config.rotateDragGuard = boolean(true, {
    label = 'End rotate drag when the mouse is lost',
    description = 'Stops rotating the character when the cursor leaves the game window, the window loses focus, or the mouse button is released out of sight. Turn off to use the plain press/release drag.',
    live = true,
})

-- How drag-to-rotate is read.
-- 'capture' (default): the cursor is hidden for the drag and held near the screen
-- centre, so it can never reach the edge of the window or carry over onto a second
-- monitor, and a drag never stops at an edge. Lua reads the cursor only while the
-- button is held (one thread that exists between press and release), turns the
-- character from how far it moved, and pulls it back to the centre the same frame;
-- on release it is put back where the drag began.
-- 'plain': the NUI turns the character from the mouse movement it sees
-- (movementX, batched to one message per frame) and never touches the cursor: the
-- game script runs no per-frame loop, never calls SetCursorLocation and never
-- changes NUI focus, so the one cursor the NUI draws (see rotateDragCursor) stays
-- steady for the whole drag. The trade-off is that the cursor is free to leave the
-- game window (onto another monitor in windowed mode) and stops at the screen edge.
-- The other modes keep rotating at the edge by moving the cursor themselves, which
-- makes a visible cursor jump and flicker between arrow and hand, so while one of
-- them is active the cursor is always hidden for the drag (rotateDragCursor is
-- ignored). 'recenter': the NUI asks Lua to put it back at the centre near an edge.
-- 'pointer' asks the browser for pointer lock, which FiveM refuses, so it falls
-- back to recenter. 'controls' hides the cursor and reads the mouse as a game
-- control (it toggles NUI focus). Read each time the menu opens.
Config.rotateMode = config and config.enum('capture', {
    options = { 'plain', 'capture', 'pointer', 'controls', 'recenter' },
    label = 'Rotate drag mode',
    description = "How rotating the character with the mouse is read. capture (default): the cursor is hidden and held at the centre while you drag, so it cannot leave the game window and rotation never stops at an edge. plain: the cursor is never moved, so it stays one steady icon for the whole drag, but it can leave the window and stops at the screen edge. pointer: browser pointer lock, which FiveM refuses, so it recentres near the edge instead. controls: the cursor is hidden and the game reads the mouse (switches NUI focus). recenter: the cursor is hidden and moved back to the centre near the edge. Every mode except plain hides the cursor while dragging.",
    live = true,
}) or 'capture'

-- Per-menu override of Config.rotateMode, keyed by the menu's service: clothing
-- (clothing shops and wardrobes), barber and hairdresser (barber and hairdresser
-- shops; which of the two opens follows the character's model), tattoo, and creation
-- (character creation and admin sessions). Unset follows Config.rotateMode.
-- Every menu follows Config.rotateMode, 'capture' by default: the hidden cursor is held
-- at the centre so a drag never stops at a screen edge or leaves the game window. The
-- drag turns the ped, not the camera (rotateTurnsPed), so the centre pulls cannot jolt
-- the camera. Set a menu to 'plain' to leave the cursor alone there (it can then leave a
-- windowed game). Capture's thread only runs while the mouse button is held in that
-- menu and stops on release or close.
-- Read each time a menu opens.
local ROTATE_MODES = { 'plain', 'capture', 'pointer', 'controls', 'recenter' }
local function rotateModeFor(default, label, menu)
    return config and config.optional(default, config.enum(default or 'plain', { options = ROTATE_MODES }), {
        label = label,
        description = ('Rotate drag mode used in %s, overriding Rotate drag mode. Leave unset to use Rotate drag mode. capture holds the hidden cursor at the screen centre while you drag, so it cannot leave the window; plain never moves the cursor, so it can.'):format(menu),
        live = true,
    }) or default
end
Config.rotateModeByService = {
    clothing = rotateModeFor(nil, 'Rotate drag mode: clothing shops', 'clothing shops and wardrobes'),
    barber = rotateModeFor(nil, 'Rotate drag mode: barber', 'barbers and hairdressers (male characters)'),
    hairdresser = rotateModeFor(nil, 'Rotate drag mode: hairdresser', 'barbers and hairdressers (female characters)'),
    tattoo = rotateModeFor(nil, 'Rotate drag mode: tattoo studio', 'tattoo studios'),
    creation = rotateModeFor(nil, 'Rotate drag mode: character creation', 'character creation and admin sessions'),
}

-- Every rotateMode. A drag turns the ped's heading and the camera stays where the
-- menu framed it (clear of walls: the occlusion check places that framing), so
-- rotating can never swing the camera through a wall or the floor of a small
-- shop. The heading the menu opened with is put back when it closes. Off: the
-- camera orbits the ped instead, and nothing stops it passing through a wall
-- behind the ped. Read on every drag.
Config.rotateTurnsPed = boolean(true, {
    label = 'Rotating turns the character',
    description = 'Dragging to rotate turns the character while the camera stays where the menu placed it, so the camera never swings through walls or the floor in small shops. The character faces its original direction again when the menu closes. Turn off to orbit the camera around the character instead (the camera can then pass through walls behind the character).',
    live = true,
})

-- Puts the cursor back where a rotate drag began when the button is released,
-- while the cursor is hidden for the drag (rotateHideCursor, the non-plain modes,
-- or rotateDragCursor = 'hidden'), so it reappears exactly where it vanished
-- instead of wherever the hidden cursor drifted. 'capture' and 'controls' always
-- do this; the option covers 'plain', 'recenter' and 'pointer'. Read on every release.
Config.rotateRestoreCursor = boolean(true, {
    label = 'Return the cursor after rotating',
    description = 'When you let go after dragging to rotate the character, the hidden cursor reappears where you pressed the button instead of where the drag moved it. Turn off to show it wherever the drag left it.',
    live = true,
})

-- Rotation speed for the plain, capture, pointer and recenter modes (controls mode
-- has its own rotateControlsSensitivity). Multiplies the built-in 0.15 degrees per pixel.
Config.rotateSensitivity = config and config.number(1.0, {
    min = 0.1, max = 10.0,
    label = 'Rotate sensitivity',
    description = 'How fast the character turns per pixel of mouse movement while dragging to rotate (capture, pointer, recenter and plain modes). 1.0 is the default; raise it to turn faster, lower it for finer control.',
    live = true,
}) or 1.0

-- Also lets the right mouse button rotate the character, in every rotateMode.
Config.rotateRightButton = boolean(true, {
    label = 'Right mouse button rotates',
    description = 'Holding the right mouse button over the character rotates it, like the left button. Turn off to rotate with the left button only.',
    live = true,
})

-- Reverses the drag direction in every rotateMode (default: dragging right turns
-- the character clockwise, like grabbing its front).
Config.rotateInvert = boolean(false, {
    label = 'Invert rotate direction',
    description = 'Reverses which way the character turns when you drag the mouse left or right.',
    live = true,
})

-- Hides the mouse cursor for as long as a rotate drag is held, in every
-- rotateMode (capture recentres the cursor many times a second, which showed as an
-- arrow jumping to the middle of the screen). The cursor comes back on release,
-- blur, Escape and menu close. Turn off to use rotateDragCursor in plain mode.
Config.rotateHideCursor = boolean(true, {
    label = 'Hide cursor while rotating',
    description = 'Hides the mouse cursor while you hold click to rotate the character, in every rotate drag mode, and shows it again when you let go. Turn off to keep the cursor chosen by Cursor while rotating (plain drag mode only).',
    live = true,
})

-- How the cursor is hidden for a rotate drag (Config.rotateHideCursor). 'blank'
-- (default) swaps it for a fully transparent image cursor, falling back to
-- CSS `cursor: none`; FiveM's browser does not always act on `none` alone, so the
-- arrow stayed visible (and showed every jump back to the drag start). 'none' uses
-- CSS `cursor: none` only. Read each time a menu opens.
Config.rotateHideMethod = config and config.enum('blank', {
    label = 'How the cursor is hidden while rotating',
    description = 'Blank swaps the cursor for a transparent one while you hold click to rotate the character, which hides it reliably in the game. None uses the browser\'s own hidden-cursor setting, which some game builds ignore. Only used while Hide cursor while rotating is on.',
    options = {
        { value = 'blank', label = 'Transparent cursor' },
        { value = 'none', label = 'Browser none' },
    },
    live = true,
}) or 'blank'

-- Cursor shown while a rotate drag is held (rotateMode = 'plain', and Config.rotateHideCursor off). 'grabbing' pins
-- the closed-hand cursor for the whole drag (a full-screen overlay owns it, so
-- nothing under the pointer can change it); 'hidden' hides it instead. Modes that
-- move the cursor themselves always hide it, whatever this says.
Config.rotateDragCursor = config and config.enum('grabbing', {
    label = 'Cursor while rotating',
    description = 'Which cursor is shown while you hold click to rotate the character (plain drag mode; the other modes always hide it). Grabbing keeps a closed-hand cursor for the whole drag; Hidden hides the cursor until you let go.',
    options = {
        { value = 'grabbing', label = 'Grabbing hand' },
        { value = 'hidden', label = 'Hidden' },
    },
    live = true,
}) or 'grabbing'

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

-- rotateMode = 'controls' and 'capture'. Hard stop for one drag, so a missed button
-- release can never leave the menu stuck without a cursor.
Config.rotateControlsMaxSeconds = config and config.number(30.0, {
    min = 2.0, max = 300.0,
    label = 'Longest single rotate drag (controls and capture modes)',
    description = 'Safety limit in seconds: a rotate drag in controls or capture mode always ends, and the cursor returns, after this long even if no button release was detected.',
    live = true,
}) or 30.0

-- Menu (NUI) options.
Config.ui = {
    -- Shows a small "Drag to rotate · Scroll to zoom" hint near the bottom of
    -- the screen when a clothing, barber, tattoo or creator menu opens. It does
    -- not take mouse input or cover any panel, and fades after the first rotate
    -- drag or wheel zoom, or after about 8 seconds. Read each time a menu opens.
    showControlsHint = boolean(true, {
        label = 'Show camera controls hint',
        description = 'Shows a short Drag to rotate / Scroll to zoom reminder when a clothing, barber, tattoo or creator menu opens. It fades after the first rotate or zoom, or after about 8 seconds. Turn off to never show it.',
        live = true,
    }),
    -- Character creation (and admin sessions) open on the Style tab with Hair
    -- selected, so hair, hair colour, facial hair and eyebrows are visible at
    -- once instead of behind Style > Hair. Which of those parts are offered is
    -- still decided by Config.headOverlays. Off keeps the old start on Tops.
    -- The menu columns scroll with the mouse wheel anywhere over them, the arrow
    -- keys and touchpads either way; this only decides whether the grey
    -- scrollbar is drawn at their edge. Off (default) hides it. Read each time a
    -- menu opens.
    showScrollbar = boolean(false, {
        label = 'Show menu scrollbars',
        description = 'Draws a scrollbar at the edge of the menu columns when they are longer than the screen. Off by default: the columns still scroll with the mouse wheel anywhere over them and with the arrow keys.',
        live = true,
    }),
    creatorOpensOnHair = boolean(true, {
        label = 'Creator opens on hair and grooming',
        description = 'Character creation opens on the Style tab with Hair selected, so hair, hair colour, facial hair and eyebrows are shown straight away. Turn off to open on the first clothing tab instead; the hair options are then under Style > Hair. Barbers and clothing shops are unaffected.',
        live = true,
    }),
    -- Preview clothing switches stacked on the left of the menu, under My
    -- Outfits: Hat, Shirt, Pants and Shoes. Each takes that item off and puts
    -- it back, so chest hair or a new cut can be seen. Preview only: the change
    -- lives on the local ped, is never sent to the server, saved or charged,
    -- and the real clothing comes back when the switch is turned back on and
    -- whenever the menu closes (confirm, cancel, Esc, going down, resource
    -- stop). Shirt, Pants and Shoes use the matching part (top, legs, shoes) of
    -- Config.tattoo.undress.parts for the bare look; Hat clears the hat prop.
    -- Barbers and hairdressers already take the hat off when they open, so the
    -- Hat switch starts off there. Read each time a menu opens.
    --   enabled  : master switch for all of them.
    --   services : menus that show them: barber, hairdresser, clothing, creation
    --              (the tattoo studio has its own undress buttons).
    --   items    : each switch on or off.
    -- (Replaces Config.ui.barberTopToggle; setting that to false still hides the Shirt switch.)
    clothingToggles = {
        enabled = boolean(true, {
            label = 'Preview clothing switches',
            description = 'Shows Hat, Shirt, Pants and Shoes switches on the left of the menu, under My Outfits, that take that item off and put it back so hair, chest hair or a style can be seen. Preview only: nothing is saved or charged and the real clothing comes back when the menu closes. Choose the menus and the switches below.',
            live = true,
        }),
        services = config and config.list({ 'barber', 'hairdresser' }, config.string('barber'), {
            label = 'Menus with clothing switches',
            description = 'Menus that show the preview clothing switches: barber, hairdresser, clothing, creation. Barbers and hairdressers by default.',
            live = true,
        }) or { 'barber', 'hairdresser' },
        items = {
            hat = boolean(true, {
                label = 'Hat switch',
                description = 'Shows the Hat switch (takes the hat off and puts it back).',
                live = true,
            }),
            shirt = boolean(true, {
                label = 'Shirt switch',
                description = 'Shows the Shirt switch (takes the top, undershirt and gloves off and puts them back), for example to see chest hair.',
                live = true,
            }),
            pants = boolean(true, {
                label = 'Pants switch',
                description = 'Shows the Pants switch (takes the pants off and puts them back).',
                live = true,
            }),
            shoes = boolean(true, {
                label = 'Shoes switch',
                description = 'Shows the Shoes switch (takes the shoes off and puts them back).',
                live = true,
            }),
        },
    },
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
    -- Hold the character still while a menu is open: its idle fidget animations
    -- (shifting weight, looking around) are paused, it is given a stand-still
    -- task with head IK off (the player ped otherwise turns its head and upper
    -- body to follow the orbiting camera), and the camera is aimed at
    -- where the ped stands, measured once when the menu opens (and again if the
    -- model changes), instead of following its spine and head bones every frame.
    -- Following the breathing / idle animation made the whole view sway, so the
    -- ped looked like it was moving in place, most of all while rotating. Off
    -- keeps the old per-frame tracking. Read when a menu opens.
    holdStill = boolean(true, {
        label = 'Hold the character still in menus',
        description = 'Pauses the idle fidget animations, stops the character turning its head and body to look at the camera, and keeps the camera fixed on where the character stands while a clothing, barber, tattoo or creator menu is open, so the character does not sway or appear to move in place while you rotate. Turn off to let the camera follow the idle animation and leave its tasks alone, as before.',
        live = true,
    }),
    -- Frame the face and shoes zones on the ped's head and foot bones, and size
    -- the camera limits from them, instead of from the model bounding box. Fixes
    -- the face view stopping at the shoulders and the shoes view dropping under
    -- the map on female / differently sized peds. Turn off for the old
    -- spine-offset framing. Read while the camera runs.
    frameToBones = boolean(true, {
        label = 'Frame head and feet on their bones',
        description = "Centres the face and shoes camera views on the character's head and foot bones so they work for every ped model and height. Turn off to use the fixed offsets from the spine instead.",
        live = true,
    }),
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
        shoes = { boneOffset = vector3(0.0, 0.0, -1.05), camOffset = vector3(0.0, 1.0, 0.1),  fov = 35.0, track = 'feet', trackOffset = 0.06 },
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
    resetOnCategoryChange = boolean(false, {
        label = 'Move camera when changing category',
        description = 'Moves the fitting-room camera to the framing for each clothing or tattoo category when it is selected, and clears any mouse-wheel zoom. Off by default so the camera stays where the player put it; the camera buttons at the top always work.',
        live = true,
    }),
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
    -- Orbit rotation speed, tuned for the "smooth, not a jump-cut" illenium-style
    -- feel called for by UX.
    orbitDegPerSec = 90.0,
    -- Time a change of view (position, look-at height, fov, occlusion swing)
    -- takes to settle, in milliseconds. Eased, never a snap, at any frame rate.
    transitionMs = config and config.number(500, {
        min = 50, max = 3000,
        label = 'Camera transition time (ms)',
        description = 'How long the fitting-room camera takes to move when you pick Face, Torso, Legs, Shoes or Full body. Lower is snappier, higher is slower and smoother.',
        live = true,
    }) or 500,
    -- When something (a wall, a counter, a prop) is between the camera and the
    -- character, the camera tries a few angles around the front instead. This is
    -- the furthest it may swing from the front, in degrees; the side and rear
    -- candidates (up to 180) are only tried above 55. Past it, the camera
    -- pulls in instead of going round, so choosing a category never ends up
    -- looking at the back of the character.
    occlusionMaxSwing = config and config.number(55.0, {
        min = 0.0, max = 180.0,
        label = 'Furthest the camera may swing round an obstruction',
        description = 'Degrees the fitting-room camera may move away from the front of the character to avoid an obstruction. 55 keeps it in front; 180 allows the old behaviour of going round to the side or back.',
        live = true,
    }) or 55.0,
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
    enabled = boolean(true, {
        label = 'Quick clothing toggles (/c <part>)',
        description = 'Adds a chat command (default /c) with a part argument (vest, shirt, pants, shoes, hat, mask, visor, glasses, ...) that takes that clothing item off and, on a second use, puts it back. Temporary: nothing is saved. Turn off to remove the command and its chat suggestion (applies on the next resource start).',
    }),
    command = config and config.string('c', {
        label = 'Quick toggle command name',
        description = 'Chat command name without the slash. Change it if another resource already uses /c. Applies on the next resource start.',
    }) or 'c',
    chatSuggestion = boolean(true, {
        label = 'Quick toggle chat suggestion',
        description = 'Shows the command and its valid parts in the chat suggestions.',
    }),
    cooldownMs = config and config.integer(1500, {
        min = 0, max = 60000,
        label = 'Quick toggle cooldown (ms)',
        description = 'Minimum time between two uses of the command by one player. 0 disables the cooldown.',
        live = true,
    }) or 1500,
    allowDead = boolean(false, {
        label = 'Quick toggles while dead',
        description = 'Allow the command while the player is dead or downed.',
        live = true,
    }),
    allowCuffed = boolean(false, {
        label = 'Quick toggles while cuffed',
        description = 'Allow the command while handcuffed (needs kora_police; ignored if it is not running).',
        live = true,
    }),
    allowInVehicle = boolean(true, {
        label = 'Quick toggles in a vehicle',
        description = 'Allow the command while sitting in a vehicle.',
        live = true,
    }),
    animations = boolean(true, {
        label = 'Quick toggle animations',
        description = 'Plays a short clothing animation when an item is taken off or put back. Turn off for instant changes.',
        live = true,
    }),
    animationsInVehicle = boolean(false, {
        label = 'Quick toggle animations in a vehicle',
        description = 'Also play the animation while in a vehicle. Off by default: the change is instant there.',
        live = true,
    }),
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

-- Closing the menus when the player goes down.
--   enabled         : while any fitting-room menu (clothing, barber, surgeon, tattoo,
--                     outfits, admin) is open and the player enters last stand / bleed-out
--                     or dies, the menu runs the normal Cancel (preview reverted, NUI
--                     closed, camera/focus/HUD restored). Detected from kora_ambulance's
--                     `emsDown` player state bag plus a watchdog. The one-time mandatory
--                     first-character creation is never cancelled. Off = only a ped death
--                     closes the tattoo / barber-shirt menus (legacy behaviour).
--   blockOpen       : also refuse to open a menu while downed or dead (the player is told why).
--   checkIntervalMs : only used with a kora_lib that has no cache module: poll interval
--                     while a menu is open (minimum 50). Otherwise the kora_lib cache's
--                     isDead change and the state bag close the menu with no polling.
Config.closeWhenDowned = {
    enabled = boolean(true, {
        label = 'Close appearance menus when the player goes down',
        description = 'When enabled, any open clothing, barber, surgeon, tattoo or outfit menu is cancelled (preview changes reverted) as soon as the player enters last stand, bleed-out or dies. The mandatory first-character creation is never cancelled.',
        live = true,
    }),
    blockOpen = boolean(true, {
        label = 'Block opening appearance menus while downed',
        description = 'When enabled, menus cannot be opened while the player is in last stand or dead. Only applies while "Close appearance menus when the player goes down" is on.',
        live = true,
    }),
    checkIntervalMs = config and config.integer(250, {
        label = 'Downed watchdog interval (ms)',
        description = 'Only used when kora_lib has no cache module: how often, while a menu is open, the downed / dead state is polled. With the cache, menus close on its death event and the state bag without polling.',
        min = 50,
    }) or 250,
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
    for _, gender in ipairs({ 'male', 'female' }) do
        local starter = Config.starterOutfit[gender]
        starter.components = Kora.config.map(starter.components, tattooStripItem, {
            keyType = 'integer',
            live = true,
            label = ('Starter outfit clothing (%s)'):format(gender),
            description = ('Maps GTA clothing component IDs to the drawable (d) and texture (t) a new %s character starts in. Components not listed start on drawable 0. Add only valid non-negative component, drawable and texture IDs.'):format(gender),
        })
        starter.props = Kora.config.map(starter.props, tattooStripItem, {
            keyType = 'integer',
            live = true,
            label = ('Starter outfit props (%s)'):format(gender),
            description = ('Maps GTA prop slot IDs (0 hat, 1 glasses, 2 ears, 6 watch, 7 bracelet) to the drawable (d) and texture (t) a new %s character starts with. Slots not listed start empty.'):format(gender),
        })
    end
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

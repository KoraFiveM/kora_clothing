-- Coverage for the shape of Config.shops now that the interaction target is
-- zone GEOMETRY rather than a spawned clerk. kora_target's addBoxZone/addPolyZone
-- assert on their arguments (isCoordsLike, ">= 3 points" -- see
-- kora_target/client/state.lua), and those asserts fire at chunk load inside a
-- CreateThread, where the failure is a line in the server console and a shop
-- that simply never opens. Checking the config's shape here is what turns that
-- into a test failure instead.
--
-- Also guards map-legend grouping: matching named categories collapse every
-- branch of a service beneath one heading (see kora_lib/modules/blips/docs.md).
local H = dofile('test/harness.lua')

_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end

dofile('config.lua')
dofile('shared/components.lua')

local function isCoordsLike(value)
    return type(value) == 'table'
        and type(value.x) == 'number' and type(value.y) == 'number' and type(value.z) == 'number'
end

H.ok(Config.shopPeds == false, 'the decorative clerk is off by default -- the target is the storefront, not a ped')
H.ok(isCoordsLike(Config.shopZoneDefault.size), 'the fallback box for a zone-less shop entry is itself a usable size')

local categoryByService = {
    clothing = 'Clothing', tattoo = 'Tattoo',
    barber = 'Grooming', hairdresser = 'Grooming',
}

for index, shop in ipairs(Config.shops) do
    local where = ('Config.shops[%d] (%s)'):format(index, tostring(shop.label))

    H.ok(Config.services[shop.service] ~= nil, ('%s names a configured service'):format(where))
    H.ok(isCoordsLike(shop.coords), ('%s coords are usable as a box centre and a blip position'):format(where))
    H.ok(type(shop.coords.w) == 'number', ('%s coords carry a heading, used as the box rotation and the clerk facing'):format(where))

    -- A shop with neither its own zone nor a usable default would register no
    -- target at all: reachable only by the nearest-shop event, which is not
    -- how a player finds a store.
    local zone = shop.zone or Config.shopZoneDefault
    H.ok(type(zone) == 'table', ('%s resolves to some zone geometry'):format(where))

    if zone.points then
        H.ok(#zone.points >= 3, ('%s polyzone has at least the 3 points addPolyZone asserts on'):format(where))
        for pointIndex, point in ipairs(zone.points) do
            H.ok(isCoordsLike(point), ('%s polyzone point %d is a table with numeric x/y/z'):format(where, pointIndex))
        end
        -- Without one of these kora_lib falls back to Config.zones.defaultPolyThickness,
        -- which is a qblib-wide number that has nothing to do with this shop's
        -- ceiling: a store traced on one floor would silently reach through it.
        H.ok(type(zone.thickness) == 'number' or (type(zone.minZ) == 'number' and type(zone.maxZ) == 'number'),
            ('%s polyzone states its own height band (thickness, or minZ+maxZ)'):format(where))
        if type(zone.thickness) == 'number' then
            H.ok(zone.thickness > 0 and zone.thickness <= 10.0,
                ('%s poly thickness is one storey of headroom, not a column through the map'):format(where))
        end
    else
        H.ok(isCoordsLike(zone.size), ('%s box size is a table with numeric x/y/z'):format(where))
        H.ok(zone.size.x > 0 and zone.size.y > 0 and zone.size.z > 0, ('%s box has real extents -- a zero extent can never be entered'):format(where))
        -- Generous, not exact: this is a storefront counter, so a box big
        -- enough to swallow the street or too small to stand in is a typo.
        H.ok(zone.size.x <= 8.0 and zone.size.y <= 8.0 and zone.size.z <= 8.0, ('%s box is a storefront, not a district'):format(where))
        H.ok(type(zone.rotation) == 'number', ('%s box rotation is set explicitly, not left to the coords heading by accident'):format(where))
    end

    local blip = shop.blip
    if blip and blip.enabled then
        H.equal(blip.category, categoryByService[shop.service], ('%s uses its canonical map category'):format(where))
        H.equal(blip.label, nil, ('%s leaves display-label composition to qblib'):format(where))
        if shop.service == 'clothing' then
            H.equal(blip.name, shop.label, ('%s supplies its storefront name separately'):format(where))
        else
            H.equal(blip.name, nil, ('%s is a generic service marker without a duplicate name'):format(where))
        end
    end
end

-- The shop's own `label` stays brand-specific: it is the kora_target prompt
-- ("Open Suburban"), not the map label, so the blip configuration must not
-- have flattened it.
local shopLabels = {}
for _, shop in ipairs(Config.shops) do
    if shop.service == 'clothing' then shopLabels[shop.label] = true end
end
local brands = 0
for _ in pairs(shopLabels) do brands = brands + 1 end
H.ok(brands > 1, 'clothing shops keep their individual brand labels for the interaction prompt')

-- Styling chairs are deliberately polygon zones. This keeps their target
-- registration consistent with the rest of the shop system while retaining a
-- small, chair-sized footprint.
for index, shop in ipairs(Config.shops) do
    if shop.service == 'barber' or shop.service == 'tattoo' then
        H.ok(shop.zone and shop.zone.points,
            ('Config.shops[%d] (%s) uses a polyzone rather than a box zone'):format(index, shop.label))
    end
end

H.finish()

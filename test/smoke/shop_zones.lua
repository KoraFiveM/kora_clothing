-- Coverage for the shape of Config.shops now that the interaction target is
-- zone GEOMETRY rather than a spawned clerk. qbtarget's addBoxZone/addPolyZone
-- assert on their arguments (isCoordsLike, ">= 3 points" -- see
-- qbtarget/client/state.lua), and those asserts fire at chunk load inside a
-- CreateThread, where the failure is a line in the server console and a shop
-- that simply never opens. Checking the config's shape here is what turns that
-- into a test failure instead.
--
-- Also guards the pause-map blip grouping: category 11 groups blips under a
-- heading taken from their own NAME, so a single differing label inside one
-- service splits the group back into individual rows (see
-- qblib/modules/blips/docs.md).
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

local labelsByService = {}

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
        -- Without one of these qblib falls back to Config.zones.defaultPolyThickness,
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
        H.equal(blip.category, 11, ('%s blip uses the grouped legend category'):format(where))
        H.ok(type(blip.label) == 'string' and #blip.label > 0, ('%s blip has a label -- it IS the legend heading'):format(where))
        labelsByService[shop.service] = labelsByService[shop.service] or {}
        labelsByService[shop.service][blip.label] = true
    end
end

-- The whole point of category 11 here: one heading per service, not one row
-- per branch. Two labels inside a service means two headings.
for service, labels in pairs(labelsByService) do
    local count = 0
    for _ in pairs(labels) do count = count + 1 end
    H.equal(count, 1, ('every %s blip shares one identical label, so the legend collapses to a single heading'):format(service))
end

-- The shop's own `label` stays brand-specific: it is the qbtarget prompt
-- ("Open Suburban"), not the legend heading, so the blip regrouping must not
-- have flattened it.
local shopLabels = {}
for _, shop in ipairs(Config.shops) do
    if shop.service == 'clothing' then shopLabels[shop.label] = true end
end
local brands = 0
for _ in pairs(shopLabels) do brands = brands + 1 end
H.ok(brands > 1, 'clothing shops keep their individual brand labels for the interaction prompt')

H.finish()

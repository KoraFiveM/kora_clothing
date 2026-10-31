-- kora_clothing server authority: fitting-room bucket isolation, skin/outfit
-- persistence, and the real qb-clothing wire protocol (net events + QB
-- callback names) for third-party compat.
--
-- Session model: `sessions[src]` exists exactly while a player is inside the
-- NUI (shop, wardrobe, or the mandatory first-character flow). It is the sole
-- source of truth for "what bucket do I restore them to" and "are they
-- allowed to cancel" -- never trust the client's own idea of session state.

local sessions = {} -- [src] = { mode, mandatory, previousBucket, citizenid, shopIndex }
local openingSessions = {} -- [src] = request identity while appearance reads are pending
local previewCache = {} -- [src][citizenid] = { model, skin }; pre-login selection-session cache
local pendingAdminSessions = {} -- [src] = { service, expiresAt }; minted only by kora_admin's server export

local function citizenIdFor(src)
    local ok, citizenid = pcall(function() return exports.kora_core:getPlayerData(src, { 'citizenid' }) end)
    if not ok or type(citizenid) ~= 'string' or citizenid == '' then return nil end
    return citizenid
end

local function decode(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' then return {} end
    local ok, out = pcall(json.decode, value)
    return (ok and type(out) == 'table') and out or {}
end

local function encode(value)
    local ok, out = pcall(json.encode, value or {})
    return ok and out or '{}'
end

local function defaultModelFor(src)
    local ok, charinfo = pcall(function() return exports.kora_core:getPlayerData(src, { 'charinfo' }) end)
    local gender = ok and type(charinfo) == 'table' and charinfo.gender or 0
    return gender == 1 and Shared.models.female or Shared.models.male
end

-- --- persistence-backed reads/writes ---

local function dbGetSkin(citizenid, src, context)
    local row, err = QB.sql.single('SELECT `model`, `skin` FROM `playerskins` WHERE `citizenid` = ?', { citizenid })
    if err then
        if src and context and citizenIdFor(src) == citizenid
            and (openingSessions[src] == context or sessions[src] == context) then
            TriggerClientEvent('qbclothing:client:sessionError', src, 'Could not load your saved appearance. Please try again.')
        end
        error(err, 0)
    end
    if not row then return nil end
    return { model = row.model, skin = decode(row.skin) }
end

local function dbSetSkin(citizenid, model, skin)
    local ok, result = pcall(QB.sql.execute,
        'INSERT INTO `playerskins` (`citizenid`, `model`, `skin`) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `model` = VALUES(`model`), `skin` = VALUES(`skin`)',
        { citizenid, model, encode(skin) })
    return ok and result ~= nil
end

local function dbListOutfits(citizenid)
    return QB.sql.query(
        'SELECT `id`, `outfitname`, `model` FROM `playeroutfits` WHERE `citizenid` = ? ORDER BY `id` DESC',
        { citizenid }
    ) or {}
end

local function dbCountOutfits(citizenid)
    return QB.sql.scalar('SELECT COUNT(*) FROM `playeroutfits` WHERE `citizenid` = ?', { citizenid }) or 0
end

local function dbGetOutfit(citizenid, id)
    return QB.sql.single(
        'SELECT `id`, `outfitname`, `model`, `skin` FROM `playeroutfits` WHERE `citizenid` = ? AND `id` = ?',
        { citizenid, id }
    )
end

-- Full skin blobs for ownership checks (see skinsMatch/ownedOutfitMatch) --
-- deliberately separate from dbListOutfits, which only needs id/name/model
-- for the NUI's outfit list and would waste bandwidth decoding skin JSON it
-- never uses.
local function dbListOutfitSkins(citizenid)
    return QB.sql.query('SELECT `model`, `skin` FROM `playeroutfits` WHERE `citizenid` = ?', { citizenid }) or {}
end

local function dbInsertOutfit(citizenid, name, model, skin)
    return QB.sql.insert(
        'INSERT INTO `playeroutfits` (`citizenid`, `outfitname`, `model`, `skin`) VALUES (?, ?, ?, ?)',
        { citizenid, name, model, encode(skin) }
    )
end

local function dbDeleteOutfit(citizenid, id)
    local ok, result = pcall(QB.sql.execute,
        'DELETE FROM `playeroutfits` WHERE `citizenid` = ? AND `id` = ?', { citizenid, id })
    return ok and result ~= nil
end

-- The client target is a shop's configured zone, not necessarily the single
-- `coords` point retained for its blip/decorative clerk.  Keep the server
-- authority aligned with that geometry: otherwise a player can see and select
-- a polygon target across a shop floor, only for requestSession to reject it
-- because they are more than Config.interactDistance from the old counter.
local function pointInPolygon(x, y, points)
    local inside = false
    local previous = points[#points]

    for _, point in ipairs(points) do
        if (point.y > y) ~= (previous.y > y) then
            local crossingX = (previous.x - point.x) * (y - point.y) / (previous.y - point.y) + point.x
            if x < crossingX then inside = not inside end
        end
        previous = point
    end

    return inside
end

local function withinShopZone(pos, zone, shopCoords)
    if not zone then return false end

    if zone.points then
        local minZ, maxZ
        if type(zone.minZ) == 'number' and type(zone.maxZ) == 'number' then
            minZ, maxZ = zone.minZ, zone.maxZ
        elseif type(zone.thickness) == 'number' then
            minZ = zone.points[1].z
            for _, point in ipairs(zone.points) do minZ = math.min(minZ, point.z) end
            maxZ = minZ + zone.thickness
        else
            return false
        end

        return pos.z >= minZ and pos.z <= maxZ and pointInPolygon(pos.x, pos.y, zone.points)
    end

    local size = zone.size
    if not size then return false end

    -- kora_lib box zones rotate their XY footprint around shop.coords and use a
    -- vertical band centred on its Z coordinate.
    local rotation = math.rad(zone.rotation or shopCoords.w or 0.0)
    local dx, dy = pos.x - shopCoords.x, pos.y - shopCoords.y
    local localX = dx * math.cos(rotation) + dy * math.sin(rotation)
    local localY = -dx * math.sin(rotation) + dy * math.cos(rotation)
    local halfZ = size.z / 2

    return math.abs(localX) <= size.x / 2
        and math.abs(localY) <= size.y / 2
        and pos.z >= shopCoords.z - halfZ
        and pos.z <= shopCoords.z + halfZ
end

local function nearShop(src, shop)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    local pos = GetEntityCoords(ped)

    local zone = shop.zone or Config.shopZoneDefault
    if withinShopZone(pos, zone, shop.coords) then return true end

    -- Keep the historical counter-radius fallback for legacy locations that
    -- have no zone data. Configured zones are deliberately not widened here:
    -- target visibility already enforces their client-side distance, while
    -- this check remains the authoritative server-side boundary.
    if zone then return false end
    local dx, dy, dz = pos.x - shop.coords.x, pos.y - shop.coords.y, pos.z - shop.coords.z
    return (dx * dx + dy * dy + dz * dz) <= (Config.interactDistance + 1.0) ^ 2
end

-- --- sanitisation ---

-- Clamps to a generous plausible range. The true per-model/per-slot cap can
-- only be queried from a live ped (client-side natives), so this is a coarse
-- anti-garbage bound, not a per-model authority -- the client's own live
-- query is what keeps a legitimate player's selection in range.
local function clampIndex(value)
    value = tonumber(value)
    if not value then return 0 end
    return QB.util.clamp(math.floor(value), -1, 999)
end

local function sanitiseSkin(rawSkin, model)
    -- hairColor/hairHighlight are palette indices, not drawable/texture pairs,
    -- so they get Shared.clampHairColor rather than clampIndex: clampIndex's
    -- -1 sentinel means "no prop" and is a legal value there, while a -1 (or a
    -- 500) handed to SetPedHairColor is not "no hair colour" -- it is an
    -- out-of-palette read. Always present, defaulting to index 0, so every
    -- downstream diff/equality check can compare them unconditionally.
    local skin = { components = {}, props = {}, tattoos = {}, hairColor = 0, hairHighlight = 0, head = Shared.sanitiseHead() }
    if type(rawSkin) ~= 'table' then return skin end

    skin.hairColor = Shared.clampHairColor(rawSkin.hairColor)
    skin.hairHighlight = Shared.clampHairColor(rawSkin.hairHighlight)
    skin.head = Shared.sanitiseHead(rawSkin.head)

    local components = type(rawSkin.components) == 'table' and rawSkin.components or {}
    for id in pairs(Shared.components) do
        local entry = components[tostring(id)]
        if type(entry) == 'table' then
            skin.components[tostring(id)] = { d = clampIndex(entry.d), t = math.max(0, clampIndex(entry.t)) }
        end
    end

    local props = type(rawSkin.props) == 'table' and rawSkin.props or {}
    for id in pairs(Shared.props) do
        local entry = props[tostring(id)]
        if type(entry) == 'table' then
            skin.props[tostring(id)] = { d = clampIndex(entry.d), t = math.max(0, clampIndex(entry.t)) }
        end
    end

    local seen = {}
    for _, id in ipairs(type(rawSkin.tattoos) == 'table' and rawSkin.tattoos or {}) do
        if not seen[id] and Shared.tattooById(model, id) then
            seen[id] = true
            skin.tattoos[#skin.tattoos + 1] = id
        end
    end

    return skin
end

local function serviceConfig(service)
    return Config.services[service] or Config.services.clothing
end

local function serviceAllowsModel(service, model)
    local required = serviceConfig(service).model
    return not required or required == Shared.modelGender(model)
end

local function idAllowed(ids, id)
    for _, candidate in ipairs(ids or {}) do
        if candidate == id then return true end
    end
    return false
end

-- Specialist sessions may only alter their own fields. This merge is server
-- authority: a modified browser can submit every drawable, but it cannot turn
-- a barber visit into a clothing editor.
local function mergeServiceSkin(before, requested, service, model)
    local policy = serviceConfig(service)
    if policy.all then
        -- Even creation honours Config.headOverlays, so a hidden overlay cannot be forced by a modified client.
        requested.head = Shared.mergeHead(policy, before and before.head, requested.head)
        return requested
    end
    if not before then return requested end

    local merged = { components = {}, props = {}, tattoos = {} }
    for id in pairs(Shared.components) do
        local key = tostring(id)
        merged.components[key] = idAllowed(policy.components, id) and requested.components[key] or before.components[key]
    end
    for id in pairs(Shared.props) do
        local key = tostring(id)
        merged.props[key] = idAllowed(policy.props, id) and requested.props[key] or before.props[key]
    end
    -- Hair colour rides on the hair component's own whitelist entry: whoever
    -- may change component 2 may recolour it, and nobody else can. Without
    -- this a clothing shop could recolour hair a barber charges for.
    local hairSource = idAllowed(policy.components, 2) and requested or before
    merged.hairColor, merged.hairHighlight = hairSource.hairColor, hairSource.hairHighlight
    -- Skin tone stays creation-only; overlays follow Config.headOverlays.barber.
    merged.head = Shared.mergeHead(policy, before.head, requested.head)
    merged.tattoos = policy.tattoos and requested.tattoos or before.tattoos
    return sanitiseSkin(merged, model)
end

-- One price per CATEGORY that actually changed, not per component -- matches
-- Config.shop.prices' granularity and real qb-clothing's "you pay once per
-- section you touched" shop pricing.
local function priceDiff(previousSkin, newSkin, prices)
    local touchedCategories = {}

    local function markIfChanged(catalogue, previousBag, newBag)
        for id, meta in pairs(catalogue) do
            local key = tostring(id)
            local before, after = previousBag[key], newBag[key]
            local changed = (before == nil) ~= (after == nil)
            if not changed and before and after then
                changed = before.d ~= after.d or before.t ~= after.t
            end
            if changed then touchedCategories[meta.category] = true end
        end
    end

    markIfChanged(Shared.components, previousSkin.components or {}, newSkin.components or {})
    markIfChanged(Shared.props, previousSkin.props or {}, newSkin.props or {})

    -- Hair colour belongs to the hair component but is not a drawable/texture
    -- pair, so markIfChanged cannot see it -- without this a barber visit that
    -- only recoloured the hair would be free.
    if previousSkin.hairColor ~= newSkin.hairColor or previousSkin.hairHighlight ~= newSkin.hairHighlight then
        touchedCategories[Shared.components[2].category] = true
    end

    -- Eyebrow/facial-hair edits are grooming, priced with the hair category.
    local previousHead, newHead = Shared.sanitiseHead(previousSkin.head), Shared.sanitiseHead(newSkin.head)
    for _, overlay in ipairs(Shared.headOverlays) do
        if previousHead[overlay.style] ~= newHead[overlay.style] or previousHead[overlay.opacity] ~= newHead[overlay.opacity]
            or previousHead[overlay.color] ~= newHead[overlay.color] then
            touchedCategories[Shared.components[2].category] = true
        end
    end

    local total = 0
    for category in pairs(touchedCategories) do
        total = total + ((prices or {})[category] or 0)
    end
    return total
end

-- Additions/replacements cost their individual configured price; removal and
-- existing tattoos are free. The server resolves every id against the current
-- model's catalogue before this runs, so client prices are never trusted.
local function tattooPriceDiff(previousSkin, newSkin, model)
    local owned, total = {}, 0
    for _, id in ipairs(previousSkin.tattoos or {}) do owned[id] = true end
    for _, id in ipairs(newSkin.tattoos or {}) do
        if not owned[id] then
            local tattoo = Shared.tattooById(model, id)
            total = total + (tattoo and tattoo.price or 0)
        end
    end
    return total
end

-- Exact content equality between two already-sanitised skins (both always
-- produced by sanitiseSkin, so same shape/id-string keys) -- used to
-- recognise "this exact look is already something the player owns."
local function skinsMatch(a, b)
    local function bagsMatch(catalogue, bagA, bagB)
        for id in pairs(catalogue) do
            local key = tostring(id)
            local entryA, entryB = bagA[key], bagB[key]
            if (entryA == nil) ~= (entryB == nil) then return false end
            if entryA and (entryA.d ~= entryB.d or entryA.t ~= entryB.t) then return false end
        end
        return true
    end

    local function tattoosMatch(tattoosA, tattoosB)
        local entriesA, entriesB = {}, {}
        for _, id in ipairs(tattoosA or {}) do entriesA[id] = true end
        for _, id in ipairs(tattoosB or {}) do entriesB[id] = true end
        for id in pairs(entriesA) do if not entriesB[id] then return false end end
        for id in pairs(entriesB) do if not entriesA[id] then return false end end
        return true
    end

    -- `b` here can be a RAW decoded playeroutfits row, and rows saved before
    -- hair colour existed carry neither field, while every sanitised skin now
    -- carries index 0. Defaulting both sides keeps those legacy outfits
    -- recognised as owned instead of quietly re-pricing them.
    local function hairOf(skin) return (skin.hairColor or 0), (skin.hairHighlight or 0) end
    local aColor, aHighlight = hairOf(a)
    local bColor, bHighlight = hairOf(b)
    if aColor ~= bColor or aHighlight ~= bHighlight then return false end
    -- Legacy rows lack the overlay keys; sanitiseHead gives both sides the same defaults.
    local aHead, bHead = Shared.sanitiseHead(a.head), Shared.sanitiseHead(b.head)
    for key, value in pairs(aHead) do
        if bHead[key] ~= value then return false end
    end

    return bagsMatch(Shared.components, a.components or {}, b.components or {})
        and bagsMatch(Shared.props, a.props or {}, b.props or {})
        and tattoosMatch(a.tattoos, b.tattoos)
end

-- True if `skin`+`model` is an exact match for one of the citizen's already-
-- saved outfits -- re-wearing something you already paid for once shouldn't
-- be priced again just because it differs from whatever you currently have on.
local function ownedOutfitMatch(citizenid, model, skin)
    for _, row in ipairs(dbListOutfitSkins(citizenid)) do
        if row.model == model and skinsMatch(decode(row.skin), skin) then
            return true
        end
    end
    return false
end

-- --- bucket helpers ---

-- kora_core updates legacy bucket tracking and notifies voice subscribers too.
-- Keep the native fallback so a core outage cannot prevent fitting-room isolation.
local function setBucket(src, bucket)
    local ok = pcall(function() exports.kora_core:setPlayerBucket(src, bucket) end)
    if not ok then
        SetPlayerRoutingBucket(src, bucket)
        TriggerEvent('qbvoice:server:bucketChanged', src)
    end
end

-- Only the one-time first-character fitting room has ambient population
-- switched off (Config.bucket.disablePopulation); shop, wardrobe and admin
-- sessions share the same personal bucket but keep the world's traffic. It is
-- written on every entry, true or false, because source numbers are reused: a
-- bucket left disabled by an earlier first-character fitting must follow the
-- current mode and config. There is no restore on leave -- nobody is in the
-- bucket afterwards and the next entry rewrites it.
local function enterFittingRoom(src, mode)
    local previousBucket = GetPlayerRoutingBucket(src)
    local bucket = Config.bucket.base + src
    setBucket(src, bucket)
    local disable = mode == 'firstCharacter' and Config.bucket.disablePopulation ~= false
    pcall(SetRoutingBucketPopulationEnabled, bucket, not disable)
    return previousBucket
end

local function leaveFittingRoom(src, previousBucket)
    setBucket(src, previousBucket or 0)
end

-- --- clothing-as-item (optional, Config.clothingAsItem) ---

-- Fires when a player uses a `qbclothing_outfit` item from their inventory.
-- Equips it live and persists it as their current look, same as a direct
-- shop purchase would -- the item is deliberately NOT consumed (`return
-- false`, matching kora_inventory's own non-consumed-use convention) so it stays
-- in the inventory as a reusable garment, swappable like a real wardrobe.
local function equipFromItem(src, item)
    local info = (item and item.info) or {}
    local model = Shared.isFreemodeModel(info.model) and info.model or defaultModelFor(src)
    local skin = sanitiseSkin(info.skin, model)

    local citizenid = citizenIdFor(src)
    if not citizenid then return false end
    if not dbSetSkin(citizenid, model, skin) then
        TriggerClientEvent('qbclothing:client:sessionError', src, 'Could not save that outfit. Please try again.')
        return false
    end

    TriggerClientEvent('qbclothing:client:wearItem', src, model, skin)
    return true
end

if Config.clothingAsItem then
    CreateThread(function()
        local coreReady = QB.resources.awaitStarted('kora_core', { timeout = 30000, interval = 200 })
        if not coreReady then
            print('^1[qbclothing]^7 Config.clothingAsItem is on but qbcore did not start in time.')
            return
        end
        local itemOk = pcall(function()
            exports.kora_core:registerShared('items', Config.clothingItem.name, {
                name = Config.clothingItem.name,
                label = Config.clothingItem.label,
                weight = Config.clothingItem.weight,
                type = 'item',
                image = Config.clothingItem.image,
                unique = false,
                useable = true,
                shouldClose = true,
                description = Config.clothingItem.description,
            })
        end)
        if not itemOk then
            print('^1[qbclothing]^7 Config.clothingAsItem is on but registering the outfit item with qbcore failed.')
        end

        local inventoryReady = QB.resources.awaitStarted('kora_inventory', { timeout = 30000, interval = 200 })
        if not inventoryReady then
            print('^1[qbclothing]^7 Config.clothingAsItem is on but qbinventory did not start in time.')
            return
        end
        local useableOk = pcall(function()
            exports.kora_inventory:createUseable(Config.clothingItem.name, equipFromItem)
        end)
        if not useableOk then
            print('^1[qbclothing]^7 Config.clothingAsItem is on but qbinventory:createUseable failed -- is kora_inventory running?')
        end
    end)
end

-- Gives a boxed outfit item instead of equipping directly. Only called when
-- Config.clothingAsItem is on and kora_inventory is actually available -- the
-- caller falls back to a direct dbSetSkin equip otherwise, so an operator
-- flipping the config on without kora_inventory running degrades gracefully
-- instead of silently losing the purchase.
local function giveOutfitItem(src, model, skin, label)
    if not Config.clothingAsItem or GetResourceState('kora_inventory') ~= 'started' then return false end
    -- pcall's own success only means "the export call didn't error" --
    -- addItem itself returns (false, 'no free slot'/'too heavy'/...) on a
    -- full or over-weight inventory WITHOUT throwing, so that failure has to
    -- be read out of the wrapped function's own return value, not assumed
    -- from pcall's ok alone. Getting this wrong means charging a player and
    -- giving them nothing in return.
    local ok, added = pcall(function()
        return exports.kora_inventory:addItem(src, Config.clothingItem.name, 1, nil, {
            model = model,
            skin = skin,
            label = label,
        }, 'qbclothing-purchase')
    end)
    return ok and added == true
end

-- --- session lifecycle ---

-- Server-to-server entry point used by kora_admin after its own command has
-- resolved a target and passed the admin gate. The short-lived grant is
-- consumed by requestSession on the target's token-authenticated client flow;
-- a player cannot manufacture one by firing a public net event.
exports('OpenAdminSession', function(targetSrc, service)
    if GetInvokingResource() ~= 'kora_admin' then return false, 'only qbadmin may open a remote admin session' end
    targetSrc = tonumber(targetSrc)
    if not targetSrc or targetSrc < 1 or not citizenIdFor(targetSrc) then return false, 'target is not online' end
    if sessions[targetSrc] or openingSessions[targetSrc] then return false, 'that player already has a clothing session open' end
    if service ~= 'clothing' and service ~= 'barber' and service ~= 'tattoo' and service ~= 'creation' then
        return false, 'invalid appearance service'
    end

    local grant = { service = service, expiresAt = os.time() + 10 }
    pendingAdminSessions[targetSrc] = grant
    SetTimeout(10000, function()
        if pendingAdminSessions[targetSrc] == grant then pendingAdminSessions[targetSrc] = nil end
    end)
    TriggerClientEvent('qbclothing:client:openAdminSession', targetSrc, service)
    return true
end)

-- Session open/confirm move real money (confirmSession) and gate an
-- admin-only free fitting (requestSession's 'admin' mode) -- routed through
-- kora_lib's tokenised QB.events instead of a raw RegisterNetEvent so a static
-- exploit menu can't fire these guessable names directly; the server-side
-- checks below (session state, price computed from a DB diff, re-checked
-- admin permission) remain the actual authorization, same as before.
local function requestSession(src, mode, extra, opening)
    if mode ~= 'firstCharacter' and mode ~= 'shop' and mode ~= 'wardrobe' and mode ~= 'admin' then return end

    local citizenid = citizenIdFor(src)
    if not citizenid then return end

    local saved = dbGetSkin(citizenid, src, opening)
    if openingSessions[src] ~= opening or citizenIdFor(src) ~= citizenid then return end

    -- "firstCharacter" is a one-time free mandatory fitting for a citizen
    -- with no saved appearance yet. Without this check, a modified client
    -- could call requestSession('firstCharacter') repeatedly to keep getting
    -- a free, mandatory-mode wardrobe with no purchase required -- downgrade
    -- to a normal (paid, cancellable) wardrobe session once one exists.
    if mode == 'firstCharacter' and saved then return end

    local shopIndex, shopLabel, service, free
    if mode == 'shop' then
        -- New callers pass { shopId = n }; numeric input remains supported by
        -- the legacy qb-clothing event/export. Only the configured shop id is
        -- accepted -- service/free/category policy is never client-supplied.
        shopIndex = tonumber(type(extra) == 'table' and extra.shopId or extra)
        local shop = shopIndex and Config.shops[shopIndex]
        if not shop then return end
        if not nearShop(src, shop) then return end
        shopLabel = shop.label
        service = shop.service or 'clothing'
        free = shop.free == true
    elseif mode == 'firstCharacter' then
        service = 'creation'
        free = true
    elseif mode == 'admin' then
        local requested = type(extra) == 'table' and extra.service or nil
        local grant = pendingAdminSessions[src]
        local selfAuthorized = exports.kora_core:hasPermission(src, 'admin')
        if not selfAuthorized then
            if not grant or grant.expiresAt < os.time() or grant.service ~= requested then return end
            pendingAdminSessions[src] = nil
        end
        service = requested or 'creation'
        free = true
    else
        -- Wardrobes can manage clothing looks but must not bypass specialist
        -- hair/tattoo stores.
        service = 'clothing'
    end

    if not Config.services[service] then return end

    local model = (saved and saved.model) or defaultModelFor(src)
    -- Grooming locations share one player-facing service. Their configured
    -- barber/hairdresser value selects the shop presentation, while the
    -- player's freemode model selects the server-authoritative hair policy.
    -- Apply this to normal target interactions as well as admin sessions so a
    -- player is not rejected merely for using the other styling location.
    local modelGender = Shared.modelGender(model)
    if (service == 'barber' or service == 'hairdresser') and modelGender then
        service = modelGender == 'female' and 'hairdresser' or 'barber'
    end
    if not serviceAllowsModel(service, model) then
        TriggerClientEvent('qbclothing:client:sessionError', src,
            service == 'barber' and 'Barbers are available to male freemode models only.' or 'Hairdressers are available to female freemode models only.')
        return
    end

    local skin = sanitiseSkin((saved and saved.skin) or {}, model)
    local moneyOk, money = pcall(function() return exports.kora_core:getPlayerData(src, { 'money' }) end)
    local outfits = dbListOutfits(citizenid)
    if openingSessions[src] ~= opening or citizenIdFor(src) ~= citizenid then return end

    -- Finish all database reads before capturing the bucket and publishing the session.
    local previousBucket = enterFittingRoom(src, mode)
    sessions[src] = {
        mode = mode,
        mandatory = mode == 'firstCharacter',
        previousBucket = previousBucket,
        citizenid = citizenid,
        shopIndex = shopIndex,
        service = service,
        free = free == true,
    }

    TriggerClientEvent('qbclothing:client:openSession', src, {
        mode = mode,
        service = service,
        free = free == true,
        mandatory = sessions[src].mandatory,
        shopLabel = shopLabel,
        model = model,
        skin = skin,
        outfits = outfits,
        prices = serviceConfig(service).prices or {},
        tattoos = serviceConfig(service).tattoos and Shared.tattoosFor(model) or {},
        currency = Config.shop.currency,
        money = moneyOk and money or nil,
    })
end

QB.events.register('qbclothing:server:requestSession', function(src, mode, extra)
    if sessions[src] then return end
    if openingSessions[src] then return end

    local opening = {}
    openingSessions[src] = opening
    local ok, err = pcall(requestSession, src, mode, extra, opening)
    if openingSessions[src] == opening then openingSessions[src] = nil end
    if not ok then error(err, 0) end
end)

AddEventHandler('playerDropped', function()
    pendingAdminSessions[source] = nil
end)

QB.callback.register('qbclothing:server:getOutfitSkin', function(src, id)
    local session = sessions[src]
    if not session then return nil end
    local row = dbGetOutfit(session.citizenid, tonumber(id) or -1)
    if not row then return nil end
    return row.model, decode(row.skin)
end)

QB.events.register('qbclothing:server:deleteOutfit', function(src, id)
    local session = sessions[src]
    if not session then return end
    id = tonumber(id)
    if not id then return end

    if not dbDeleteOutfit(session.citizenid, id) then
        TriggerClientEvent('qbclothing:client:sessionError', src, 'Could not delete that outfit. Please try again.')
        return
    end
    TriggerClientEvent('qbclothing:client:outfitsUpdated', src, dbListOutfits(session.citizenid))
end)

local function isCurrentSession(src, session)
    return sessions[src] == session and citizenIdFor(src) == session.citizenid
end

QB.events.register('qbclothing:server:confirmSession', function(src, payload)
    local session = sessions[src]
    if not session then return end
    if type(payload) ~= 'table' then return end

    -- Re-read from the DB rather than trusting anything cached from session
    -- open -- the authoritative "before" state for both pricing and (if this
    -- ends up boxed as an item instead of worn) what to revert the live ped to.
    local before = dbGetSkin(session.citizenid, src, session)
    if not isCurrentSession(src, session) then return end
    local beforeModel = (before and before.model) or defaultModelFor(src)
    -- Normal sessions cannot swap a model; that closes a model-spoofing hole
    -- and keeps barber/hairdresser model policy meaningful.
    local model = session.mode == 'firstCharacter' and defaultModelFor(src) or beforeModel
    local beforeSkin = sanitiseSkin((before and before.skin) or {}, model)
    local requestedSkin = sanitiseSkin(payload.skin, model)
    local newSkin = mergeServiceSkin(before and beforeSkin or nil, requestedSkin, session.service, model)

    -- Priced for every mode except the one-time free "firstCharacter" fitting
    -- -- NOT just 'shop'. A live component editor is otherwise identical
    -- between shop/wardrobe sessions, so gating payment on the mode label
    -- alone would let a player dress in brand-new items for free simply by
    -- opening the wardrobe instead of a shop. Also skipped when `before` is
    -- nil (no playerskins row exists yet outside the firstCharacter flow --
    -- e.g. a pre-existing citizen from before kora_clothing was installed, or a
    -- third-party script opening a session directly): `beforeSkin` in that
    -- case is an EMPTY placeholder, not the citizen's real current look, and
    -- diffing every category against "nothing" would charge for every
    -- category on a no-op confirm. Treat it as a one-time free sync instead.
    -- And skipped entirely when the confirmed look is an exact match for an
    -- outfit this citizen already owns (saved to playeroutfits before) --
    -- you paid for those pieces once; re-wearing them isn't a new purchase.
    local chargedAmount = 0
    local needsPayment = not session.free and session.mode ~= 'firstCharacter' and before and not ownedOutfitMatch(session.citizenid, model, newSkin)
    if not isCurrentSession(src, session) then return end
    if needsPayment then
        local price = priceDiff(beforeSkin, newSkin, serviceConfig(session.service).prices)
        if serviceConfig(session.service).tattoos then
            price = price + tattooPriceDiff(beforeSkin, newSkin, model)
        end
        if price > 0 then
            local paid, err = exports.kora_core:removeMoney(src, Config.shop.currency, price, 'qbclothing-purchase')
            if not isCurrentSession(src, session) then return end
            if not paid then
                TriggerClientEvent('qbclothing:client:sessionError', src, err or 'You cannot afford this outfit.')
                return
            end
            chargedAmount = price
        end
    end

    local saveName
    if type(payload.saveName) == 'string' then
        saveName = payload.saveName:sub(1, 50):gsub('^%s+', ''):gsub('%s+$', '')
        if #saveName == 0 then saveName = nil end
    end

    -- The one-time free fitting always equips directly -- there's nothing to
    -- box up yet on a character that owns nothing. Otherwise, when enabled,
    -- give a physical item instead of silently changing the persisted look.
    local wantsBox = not session.free and session.mode ~= 'firstCharacter' and Config.clothingAsItem
    local boxed = wantsBox and giveOutfitItem(src, model, newSkin, saveName or session.shopLabel or 'Outfit')
    if wantsBox and not isCurrentSession(src, session) then return end

    if not boxed then
        -- Falls through here both when boxing was never wanted (feature off)
        -- and when it WAS wanted but failed (kora_inventory not running, or the
        -- player's inventory couldn't fit it) -- the latter still needs to
        -- equip directly rather than silently losing an already-paid purchase.
        local persisted = dbSetSkin(session.citizenid, model, newSkin)
        if not isCurrentSession(src, session) then return end
        if not persisted then
            if chargedAmount > 0 then
                exports.kora_core:addMoney(src, Config.shop.currency, chargedAmount, 'qbclothing-persistence-refund')
                if not isCurrentSession(src, session) then return end
            end
            TriggerClientEvent('qbclothing:client:sessionError', src, 'Could not save your outfit. You were not charged.')
            return
        end
        if wantsBox then
            TriggerClientEvent('qbclothing:client:sessionError', src, "Couldn't fit that in your inventory -- equipped it directly instead.")
        end
    end

    if saveName then
        local count = dbCountOutfits(session.citizenid)
        if not isCurrentSession(src, session) then return end
        if count >= Config.wardrobe.maxOutfits then
            TriggerClientEvent('qbclothing:client:sessionError', src, 'Outfit slots are full.')
        else
            local outfitId = dbInsertOutfit(session.citizenid, saveName, model, newSkin)
            if not isCurrentSession(src, session) then return end
            if not outfitId then
                TriggerClientEvent('qbclothing:client:sessionError', src, 'Your outfit was equipped, but the named preset could not be saved.')
            end
        end
    end

    leaveFittingRoom(src, session.previousBucket)
    sessions[src] = nil
    TriggerClientEvent('qbclothing:client:closeSession', src, {
        ok = true,
        -- Tried-on-but-boxed: the live ped is currently wearing the new look,
        -- but it was purchased as an item, not equipped -- revert to whatever
        -- was actually equipped before this session.
        revertTo = boxed and { model = beforeModel, skin = beforeSkin } or nil,
    })
end)

QB.events.register('qbclothing:server:cancelSession', function(src)
    local session = sessions[src]
    if not session or session.mandatory then return end

    leaveFittingRoom(src, session.previousBucket)
    sessions[src] = nil
    TriggerClientEvent('qbclothing:client:closeSession', src, { ok = true, cancelled = true })
end)

-- --- real qb-clothing / qb-multicharacter compat callbacks ---

-- Real signature: cb(model, skin). kora_lib's QB.callback is return-value based
-- (see kora_core/compat/server/qb-multicharacter.lua's own getSkin stub), so a
-- handler returning `model, skin` is what QB.callback.trigger(...) surfaces
-- to a caller using the modern trigger style; QBCore.Functions.CreateCallback
-- compat (kora_core/compat/server/qb-core.lua:177) is a thin wrapper over the
-- same registry, so legacy `cb(model, skin)`-style callers work too.
QB.callback.register('qb-clothing:server:getSkin', function(src)
    local citizenid = citizenIdFor(src)
    if not citizenid then return nil end
    local saved = dbGetSkin(citizenid)
    if not saved then return nil end
    -- The only read path that used to skip sanitiseSkin -- this feeds the
    -- client's spawn-time applyModel/applySkin directly, so a stale/malformed
    -- `playerskins.skin` row (an old clothing pack, a hand-edited row) went
    -- straight onto SetPedComponentVariation/SetPedPropIndex unclamped. Every
    -- other read path (wardrobe/shop open, outfit apply) already sanitises.
    return saved.model, sanitiseSkin(saved.skin, saved.model)
end)

-- Overrides kora_core's own honest "no clothing module exists" stub
-- (compat/server/qb-multicharacter.lua) now that one does. QB.callback.register
-- is a plain last-writer-wins overwrite (kora_lib/local/callback/server.lua).
-- Explicitly unregister the documented placeholder first: this replacement
-- is intentional, so it should not emit kora_lib's cross-resource collision
-- warning intended for accidental namespace reuse. Powers kora_multichar's
-- character-select preview camera.
QB.callback.register('qb-multicharacter:server:getSkin', function(_src, citizenid)
    local src = _src
    if type(citizenid) ~= 'string' then return nil end
    local ok, owned = pcall(function() return exports.kora_core:ownsCharacter(src, citizenid) end)
    if not ok or owned ~= true then return nil end

    local byCitizen = previewCache[src]
    if not byCitizen then byCitizen = {}; previewCache[src] = byCitizen end
    local cached = byCitizen[citizenid]
    if cached then return cached.model, cached.skin end

    local saved = dbGetSkin(citizenid)
    if not saved then return nil end
    if not Shared.isFreemodeModel(saved.model) then return nil end
    local skin = sanitiseSkin(saved.skin, saved.model)
    byCitizen[citizenid] = { model = saved.model, skin = skin }
    return saved.model, skin
end, { replace = true, rateLimit = { max = 20, window = 10000 } })

-- A reconnect is not required to invalidate selection previews. The
-- kora_multichar server clears its authoritative mode after spawn/cleanup; drop
-- that source's cached pre-login reads at the same boundary so a later return
-- to character selection cannot see an outfit saved during this session.
AddStateBagChangeHandler('qbmultichar:mode', nil, function(bagName, _, value)
    -- A cleared mode is falsy: `false` from kora_multichar's writeMode, or nil on
    -- a server whose kora_multichar predates that change.
    if value or type(bagName) ~= 'string' then return end
    local src = tonumber(bagName:match('^player:(%d+)$'))
    if src then previewCache[src] = nil end
end)

-- --- cleanup ---

AddEventHandler('playerDropped', function()
    openingSessions[source] = nil
    sessions[source] = nil
    previewCache[source] = nil
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    openingSessions[src] = nil
    local session = sessions[src]
    sessions[src] = nil
    if not session or not GetPlayerName(src) then return end

    -- Character logout retires even a mandatory fitting before the next character.
    leaveFittingRoom(src, session.previousBucket)
    TriggerClientEvent('qbclothing:client:closeSession', src, { ok = true, cancelled = true })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    openingSessions = {}
    for src, session in pairs(sessions) do
        pcall(leaveFittingRoom, src, session.previousBucket)
    end
end)

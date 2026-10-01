-- Execute the real server handlers with controlled SQL waits. Bucket natives
-- only record arguments; this checks Lua session ownership, not live Cfx effects.
local H = dofile('test/harness.lua')
vector3 = function(x, y, z) return { x = x, y = y, z = z } end
vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
dofile('config.lua')
dofile('shared/components.lua')

local events, handlers, public = {}, {}, {}
local players = {
    [7] = { citizenid = 'first', charinfo = { gender = 0 }, money = { cash = 1000 } },
    [8] = { citizenid = 'other', charinfo = { gender = 1 }, money = { cash = 1000 } },
}
local bucketNotices, rawBucketAllowed = {}, false
local closes = {}
local buckets, moves, opens = { [7] = 42, [8] = 85 }, {}, {}
local holdSkin, holdOutfits, failSkin, failOutfits, admin = false, false, false, false, false
local returnedSkinError
local sessionErrors = {}
local skinReads, outfitReads, writes = 0, 0, 0
local saved = { model = Shared.models.male, skin = {} }
local outfits = { { id = 9, outfitname = 'Owned', model = Shared.models.male } }
local core = {
    getPlayerData = function(_, src, fields) return players[src] and players[src][fields[1]] end,
    hasPermission = function() return admin end,
    removeMoney = function() error('unchanged appearance must not charge') end,
}
local function setBucket(_, src, bucket)
    buckets[src] = bucket
    moves[#moves + 1] = { src = src, bucket = bucket }
end
TriggerEvent = function(name, src)
    if name == 'qbvoice:server:bucketChanged' then bucketNotices[#bucketNotices + 1] = { src = src, bucket = buckets[src] } end
end
local function compatBucket(...)
    setBucket(...)
    TriggerEvent('qbvoice:server:bucketChanged', select(2, ...))
end
-- FiveM exposes a callable exports table; the metatable only adapts that host API.
exports = setmetatable({ qbcore = core, ['qb-core'] = { SetPlayerBucket = compatBucket } }, {
    __call = function(_, name, callback) public[name] = callback end,
})
GetPlayerRoutingBucket = function(src) return buckets[src] end
SetPlayerRoutingBucket = function(src, bucket)
    assert(rawBucketAllowed, 'compat bucket export should be used')
    setBucket(nil, src, bucket)
end
GetCurrentResourceName = function() return 'qbclothing' end
GetInvokingResource = function() return 'qbadmin' end
GetPlayerName = function(src) return players[src] and 'connected player' end
GetPlayerPed = function(src) return src end
DoesEntityExist = function() return true end
local position = Config.shops[2].coords
GetEntityCoords = function() return position end
CreateThread = function() error('default config must not start an item-registration thread') end
SetTimeout = function() end
AddStateBagChangeHandler = function() end
AddEventHandler = function(name, callback)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = callback
end
TriggerClientEvent = function(name, src, payload)
    if name == 'qbclothing:client:openSession' then opens[#opens + 1] = { src = src, payload = payload } end
    if name == 'qbclothing:client:sessionError' then sessionErrors[#sessionErrors + 1] = { src = src, payload = payload } end
    if name == 'qbclothing:client:closeSession' then closes[#closes + 1] = { src = src, payload = payload } end
end
json = { encode = function() return '{}' end }
QB = {
    util = { clamp = function(value, low, high) return math.max(low, math.min(high, value)) end },
    events = { register = function(name, callback) events[name] = callback end },
    callback = { register = function() end },
    sql = {
        single = function(_, params)
            skinReads = skinReads + 1
            if failSkin then error('skin read failed') end
            if returnedSkinError then return nil, returnedSkinError end
            if holdSkin then return coroutine.yield('skin', params[1]) end
            return saved
        end,
        query = function(query, params)
            if not query:find('`outfitname`', 1, true) then return {} end
            outfitReads = outfitReads + 1
            if failOutfits then error('outfit read failed') end
            if holdOutfits then return coroutine.yield('outfits', params[1]) end
            return outfits
        end,
        execute = function() writes = writes + 1; return 1 end,
    },
}
dofile('server/server.lua')

local function emit(name, src, ...)
    source = src
    for _, callback in ipairs(handlers[name] or {}) do callback(...) end
end
local function resume(thread, ...)
    local ok, stage, citizenid = coroutine.resume(thread, ...)
    H.ok(ok, stage)
    return stage, citizenid
end
local function start(mode, extra, src)
    local thread = coroutine.create(function()
        events['qbclothing:server:requestSession'](src or 7, mode or 'wardrobe', extra)
    end)
    local stage, citizenid = resume(thread)
    return thread, stage, citizenid
end
local function cancel(src)
    events['qbclothing:server:cancelSession'](src or 7)
end

-- One request per source owns both reads; different players remain independent.
for _, exit in ipairs({ 'cancelSession', 'confirmSession' }) do
    holdSkin, holdOutfits = true, true
    local first, stage = start()
    H.equal(stage, 'skin')
    local reads = skinReads
    local duplicate = start('shop', { shopId = 2 })
    H.equal(coroutine.status(duplicate), 'dead', 'overlap must not reach SQL')
    H.equal(skinReads, reads)
    local granted, reason = public.OpenAdminSession(7, 'clothing')
    H.equal(granted, false, 'remote admin opening obeys the same reservation')
    H.equal(reason, 'that player already has a clothing session open')
    H.equal(resume(first, saved), 'outfits')
    H.equal(buckets[7], 42, 'bucket stays untouched until all reads complete')
    reads = outfitReads
    duplicate = start()
    H.equal(coroutine.status(duplicate), 'dead')
    H.equal(outfitReads, reads)
    resume(first, outfits)
    H.equal(coroutine.status(first), 'dead')
    H.equal(buckets[7], Config.bucket.base + 7)
    H.equal(opens[#opens].payload.outfits, outfits)
    H.equal(opens[#opens].payload.money, players[7].money)
    holdSkin, holdOutfits = false, false
    events['qbclothing:server:' .. exit](7, { skin = {} })
    H.equal(buckets[7], 42, exit .. ' restores the original nonzero bucket')
end
H.equal(writes, 1, 'confirmation preserves ordinary persistence')

holdSkin = true
local first = start()
local other = start('wardrobe', nil, 8)
resume(other, saved)
H.equal(buckets[8], Config.bucket.base + 8)
cancel(8)
H.equal(buckets[8], 85)
resume(first, saved)
cancel()
holdSkin = false

-- A departed request must neither open late nor release a replacement's reservation.
for _, boundary in ipairs({ 'playerDropped', 'QBCore:Server:OnPlayerUnload', 'onResourceStop' }) do
    for _, waiting in ipairs({ 'skin', 'outfits' }) do
        holdSkin, holdOutfits = waiting == 'skin', waiting == 'outfits'
        local stale, stage = start()
        H.equal(stage, waiting)
        local openCount, moveCount = #opens, #moves
        if boundary == 'onResourceStop' then
            emit(boundary, 7, 'another-resource')
            local duplicate = start()
            H.equal(coroutine.status(duplicate), 'dead', 'another resource stop retains the reservation')
            emit(boundary, 7, 'qbclothing')
        elseif boundary == 'QBCore:Server:OnPlayerUnload' then
            emit(boundary, 7, 7)
        else
            emit(boundary, 7)
        end
        local replacement = start()
        resume(stale, waiting == 'skin' and saved or outfits)
        H.equal(coroutine.status(stale), 'dead')
        H.equal(#opens, openCount, 'invalidated read cannot send a late open')
        H.equal(#moves, moveCount, 'invalidated read cannot move the player')
        local duplicate = start()
        H.equal(coroutine.status(duplicate), 'dead', 'old completion cannot clear the new reservation')
        resume(replacement, waiting == 'skin' and saved or outfits)
        H.equal(#opens, openCount + 1)
        cancel()
        H.equal(buckets[7], 42)
    end
end

-- Fresh citizen identity is also checked if a character changes during either read.
for _, waiting in ipairs({ 'skin', 'outfits' }) do
    holdSkin, holdOutfits = waiting == 'skin', waiting == 'outfits'
    local stale = start()
    local count = #opens
    players[7].citizenid = 'replacement'
    resume(stale, waiting == 'skin' and saved or outfits)
    H.equal(#opens, count)
    H.equal(buckets[7], 42)
    local replacement = start()
    resume(replacement, waiting == 'skin' and saved or outfits)
    cancel()
    players[7].citizenid = 'first'
end
holdSkin, holdOutfits = false, false

-- Every denial or thrown read releases the reservation, so a valid retry still opens.
for _, denied in ipairs({ 'mode', 'offline', 'creation', 'shop', 'distance', 'admin', 'service', 'model', 'skin-error', 'outfit-error' }) do
    local count = #opens
    local player, services = players[7], Config.services
    local mode, extra = 'wardrobe', nil
    if denied == 'mode' then mode = 'unknown'
    elseif denied == 'offline' then players[7] = nil
    elseif denied == 'creation' then mode = 'firstCharacter'
    elseif denied == 'shop' then mode, extra = 'shop', -1
    elseif denied == 'distance' then mode, extra, position = 'shop', 2, vector3(0, 0, 0)
    elseif denied == 'admin' then mode = 'admin'
    elseif denied == 'service' then Config.services = {}
    elseif denied == 'model' then admin, mode, extra = true, 'admin', { service = 'tattoo' }; Config.services.tattoo.model = 'female'
    elseif denied == 'skin-error' then failSkin = true
    elseif denied == 'outfit-error' then failOutfits = true end
    local ok, err = pcall(events['qbclothing:server:requestSession'], 7, mode, extra)
    H.equal(ok, not (failSkin or failOutfits), denied .. ' retains existing error behavior')
    if not ok then H.ok(tostring(err):find('read failed', 1, true), 'read errors remain visible') end
    H.equal(#opens, count)
    H.equal(buckets[7], 42)
    players[7], Config.services = player, services
    Config.services.tattoo.model = nil
    admin, failSkin, failOutfits, position = false, false, false, Config.shops[2].coords
    start()
    H.equal(#opens, count + 1, denied .. ' does not block a valid retry')
    cancel()
end

-- Both legacy numeric shop input and admin grants retain their existing policy.
for _, extra in ipairs({ 2, { shopId = 2 } }) do
    start('shop', extra)
    H.equal(opens[#opens].payload.service, 'clothing')
    H.equal(opens[#opens].payload.free, false)
    cancel()
end
H.equal(public.OpenAdminSession(7, 'tattoo'), true)
start('admin', { service = 'tattoo' })
H.equal(opens[#opens].payload.free, true)
cancel()
local count = #opens
start('admin', { service = 'tattoo' })
H.equal(#opens, count, 'remote admin grant remains one-use')

-- Compat-disabled installations use the raw native, with the same local notice.
saved = { model = Shared.models.male, skin = {} }
for _, available in ipairs({ true, false }) do
    rawBucketAllowed = not available
    exports['qb-core'].SetPlayerBucket = available and compatBucket or function() error('compat disabled') end
    bucketNotices = {}
    start()
    H.equal(#bucketNotices, 1)
    H.equal(bucketNotices[1].src, 7)
    H.equal(bucketNotices[1].bucket, Config.bucket.base + 7)
    bucketNotices = {}
    cancel()
    H.equal(#bucketNotices, 1)
    H.equal(bucketNotices[1].src, 7)
    H.equal(bucketNotices[1].bucket, 42)
end
exports['qb-core'].SetPlayerBucket, rawBucketAllowed = compatBucket, false

-- qbsql returns nil,error on failure; it is not an absent saved appearance.
for _, mode in ipairs({ 'firstCharacter', 'wardrobe', 'shop', 'admin' }) do
    local count, moved, errors = #opens, #moves, #sessionErrors
    returnedSkinError = 'controlled saved-skin read failed'
    local ok, err = pcall(events['qbclothing:server:requestSession'], 7, mode, { shopId = 2, service = 'creation' })
    H.equal(ok, false, 'a failed saved-skin read cannot authorize ' .. mode)
    H.ok(tostring(err):find(returnedSkinError, 1, true), 'the server retains the read diagnostic')
    H.equal(#sessionErrors, errors + 1, 'a failed open sends the existing client error response')
    H.equal(sessionErrors[#sessionErrors].src, 7)
    H.equal(sessionErrors[#sessionErrors].payload, 'Could not load your saved appearance. Please try again.')
    H.equal(sessionErrors[#sessionErrors].payload:find(returnedSkinError, 1, true), nil, 'client feedback omits the SQL diagnostic')
    H.equal(#opens, count)
    H.equal(#moves, moved)
    returnedSkinError = nil
    start()
    H.equal(#opens, count + 1, 'a failed read releases the opening reservation')
    cancel()
end

-- A retired read error must not notify or release a replacement opening.
holdSkin = true
local stale = start()
emit('QBCore:Server:OnPlayerUnload', 7, 7)
local replacement = start()
local errors = #sessionErrors
local ok, err = coroutine.resume(stale, nil, 'controlled retired read failed')
H.equal(ok, false)
H.ok(tostring(err):find('controlled retired read failed', 1, true))
H.equal(#sessionErrors, errors, 'retired opening error cannot notify a replacement')
local duplicate = start()
H.equal(coroutine.status(duplicate), 'dead', 'failed old read retains the replacement reservation')
resume(replacement, saved)
holdSkin = false
cancel()

-- Cancellation can replace a fitting while its old confirmation is reading.
start()
holdSkin = true
stale = coroutine.create(function() events['qbclothing:server:confirmSession'](7, { skin = {} }) end)
local status, stage = coroutine.resume(stale)
H.equal(status, true)
H.equal(stage, 'skin')
cancel()
replacement = start()
resume(replacement, saved)
holdSkin = false
errors = #sessionErrors
ok, err = coroutine.resume(stale, nil, 'controlled cancelled confirmation failed')
H.equal(ok, false)
H.ok(tostring(err):find('controlled cancelled confirmation failed', 1, true))
H.equal(#sessionErrors, errors, 'old confirmation error cannot notify the replacement fitting')
H.equal(buckets[7], Config.bucket.base + 7)
cancel()
H.equal(buckets[7], 42)

-- A still-recorded confirmation must not notify a different character.
start()
holdSkin = true
stale = coroutine.create(function() events['qbclothing:server:confirmSession'](7, { skin = {} }) end)
status, stage = coroutine.resume(stale)
H.equal(status, true)
H.equal(stage, 'skin')
local citizenid = players[7].citizenid
players[7].citizenid = 'replacement-character'
errors = #sessionErrors
ok, err = coroutine.resume(stale, nil, 'controlled previous-character read failed')
H.equal(ok, false)
H.equal(#sessionErrors, errors, 'old-character confirmation error cannot notify the new character')
players[7].citizenid, holdSkin = citizenid, false
cancel()

-- A failed confirmation read cannot become a free first-sync write.
start()
returnedSkinError = 'controlled confirmation read failed'
local beforeWrites, moved, errors = writes, #moves, #sessionErrors
local ok, err = pcall(events['qbclothing:server:confirmSession'], 7, { skin = {} })
H.equal(ok, false)
H.ok(tostring(err):find(returnedSkinError, 1, true))
H.equal(#sessionErrors, errors + 1, 'a failed confirmation sends the existing client error response')
H.equal(sessionErrors[#sessionErrors].src, 7)
H.equal(sessionErrors[#sessionErrors].payload, 'Could not load your saved appearance. Please try again.')
H.equal(sessionErrors[#sessionErrors].payload:find(returnedSkinError, 1, true), nil)
H.equal(writes, beforeWrites, 'failed baseline read cannot overwrite an existing skin')
H.equal(#moves, moved, 'a failed confirmation retains its existing fitting')
returnedSkinError = nil
events['qbclothing:server:confirmSession'](7, { skin = {} })
H.equal(writes, beforeWrites + 1, 'healthy confirmation retry preserves ordinary persistence')
H.equal(buckets[7], 42)

-- Character unload retires an open fitting, including mandatory creation.
for _, mode in ipairs({ 'wardrobe', 'firstCharacter' }) do
    local previousSaved = saved
    if mode == 'firstCharacter' then saved = nil end
    start(mode)
    local count, closed = #opens, #closes
    H.equal(buckets[7], Config.bucket.base + 7)
    emit('QBCore:Server:OnPlayerUnload', 7, 7)
    H.equal(buckets[7], 42, 'character unload restores the fitting-room bucket')
    H.equal(#closes, closed + 1, 'character unload closes the client fitting room')
    H.equal(closes[#closes].payload.cancelled, true, 'unload discards unsaved previews')
    emit('QBCore:Server:OnPlayerUnload', 7, 7)
    H.equal(#closes, closed + 1, 'duplicate unload is inert')
    local oldCitizen = players[7].citizenid
    players[7].citizenid, saved = 'next-character', previousSaved
    start()
    H.equal(#opens, count + 1, 'the next character can open its own fitting')
    cancel()
    H.equal(buckets[7], 42)
    players[7].citizenid, saved = oldCitizen, previousSaved
end

-- A disconnected source loses the record without native moves or client messages.
start()
local oldPlayer, closed, moved, count = players[7], #closes, #moves, #opens
players[7] = nil
emit('QBCore:Server:OnPlayerUnload', 7, 7)
H.equal(#closes, closed)
H.equal(#moves, moved)
players[7], buckets[7] = oldPlayer, 42
start()
H.equal(#opens, count + 1, 'a reused source cannot inherit the departed fitting')
cancel()

saved = nil
start('firstCharacter')
H.equal(opens[#opens].payload.mandatory, true)
cancel()
H.equal(buckets[7], Config.bucket.base + 7, 'mandatory creation cannot be cancelled')
emit('onResourceStop', 7, 'qbclothing')
H.equal(buckets[7], 42, 'resource stop retains active-session restoration')
H.finish()

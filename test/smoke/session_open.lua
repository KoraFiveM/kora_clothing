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
core.setPlayerBucket = compatBucket
exports = setmetatable({ kora_core = core }, {
    __call = function(_, name, callback) public[name] = callback end,
})
GetPlayerRoutingBucket = function(src) return buckets[src] end
local populationCalls = {}
SetRoutingBucketPopulationEnabled = function(bucket, enabled)
    populationCalls[#populationCalls + 1] = { bucket = bucket, enabled = enabled }
end
SetPlayerRoutingBucket = function(src, bucket)
    assert(rawBucketAllowed, 'compat bucket export should be used')
    setBucket(nil, src, bucket)
end
GetCurrentResourceName = function() return 'kora_clothing' end
GetInvokingResource = function() return 'kora_admin' end
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
Kora = {
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
            emit(boundary, 7, 'kora_clothing')
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

-- Config.genderLockedSalons: off keeps the model-based swap; on rejects the
-- wrong gender at shops (with a message), but never affects admin sessions,
-- creation or other services. Read live, so toggling needs no restart.
do
    local barberShop, hairShop
    for index, shop in ipairs(Config.shops) do
        if shop.service == 'barber' and not barberShop then barberShop = index end
        if shop.service == 'hairdresser' and not hairShop then hairShop = index end
    end
    H.ok(barberShop and hairShop, 'config has a barber and a hairdresser')
    local function visit(shopIndex, model, mode, extra)
        saved = mode ~= 'firstCharacter' and { model = model, skin = {} } or nil
        position = Config.shops[shopIndex or 2].coords
        local count, errors = #opens, #sessionErrors
        start(mode or 'shop', extra or { shopId = shopIndex })
        local opened = #opens > count and opens[#opens].payload.service or nil
        local err = #sessionErrors > errors and sessionErrors[#sessionErrors].payload or nil
        if opened then cancel() end
        return opened, err
    end
    local male, female = Shared.models.male, Shared.models.female
    local maleMsg = 'This barber only serves male characters. Try a hairdresser.'
    local femaleMsg = 'This hairdresser only serves female characters. Try a barber.'

    H.equal(Config.genderLockedSalons, false, 'salons are open to everyone by default')
    H.equal(visit(barberShop, female), 'hairdresser', 'off: a woman at the barber gets the hairdresser menu')
    H.equal(visit(hairShop, male), 'barber', 'off: a man at the hairdresser gets the barber menu')
    H.equal(visit(barberShop, male), 'barber', 'off: barber serves a man')
    H.equal(visit(hairShop, female), 'hairdresser', 'off: hairdresser serves a woman')

    Config.genderLockedSalons = true
    local service, err = visit(barberShop, female)
    H.equal(service, nil, 'on: a woman is not served at the barber')
    H.equal(err, maleMsg, 'on: the barber explains who it serves')
    service, err = visit(hairShop, male)
    H.equal(service, nil, 'on: a man is not served at the hairdresser')
    H.equal(err, femaleMsg, 'on: the hairdresser explains who it serves')
    H.equal(visit(barberShop, male), 'barber', 'on: barber serves a man with no swap')
    H.equal(visit(hairShop, female), 'hairdresser', 'on: hairdresser serves a woman with no swap')
    service, err = visit(barberShop, 'a_c_dog')
    H.equal(service, nil, 'on: a non-freemode ped is still rejected at the barber')
    H.ok(err, 'on: non-freemode rejection still notifies')
    service, err = visit(hairShop, 'a_c_dog')
    H.equal(service, nil, 'on: a non-freemode ped is still rejected at the hairdresser')
    H.ok(err, 'on: non-freemode rejection at the hairdresser notifies')

    -- Unaffected flows while locked.
    H.equal(visit(2, female, 'shop', { shopId = 2 }), 'clothing', 'on: clothing shops serve everyone')
    H.equal(visit(nil, female, 'wardrobe'), 'clothing', 'on: wardrobes are unaffected')
    admin = true
    H.equal(visit(nil, female, 'admin', { service = 'barber' }), 'hairdresser', 'on: admin barber session still follows the target model')
    H.equal(visit(nil, male, 'admin', { service = 'hairdresser' }), 'barber', 'on: admin hairdresser session still follows the target model')
    H.equal(visit(nil, female, 'admin', { service = 'tattoo' }), 'tattoo', 'on: admin tattoo session is unaffected')
    admin = false
    H.equal(visit(nil, female, 'firstCharacter'), 'creation', 'on: character creation is unaffected')
    -- A mandatory creation fitting cannot be cancelled; unload ends it.
    emit('QBCore:Server:OnPlayerUnload', 7, 7)

    Config.genderLockedSalons = false
    H.equal(visit(barberShop, female), 'hairdresser', 'toggling off again restores the swap')
    saved = { model = Shared.models.male, skin = {} }
    position = Config.shops[2].coords
end

-- Compat-disabled installations use the raw native, with the same local notice.
saved = { model = Shared.models.male, skin = {} }
for _, available in ipairs({ true, false }) do
    rawBucketAllowed = not available
    exports.kora_core.setPlayerBucket = available and compatBucket or function() error('compat disabled') end
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
exports.kora_core.setPlayerBucket, rawBucketAllowed = compatBucket, false

-- kora_sql returns nil,error on failure; it is not an absent saved appearance.
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

-- Successful SQL completions cannot resume a retired fitting's remaining work.
local oldSingle, oldQuery, oldExecute = Kora.sql.single, Kora.sql.query, Kora.sql.execute
local oldScalar, oldInsert, oldRemove, oldAdd = Kora.sql.scalar, Kora.sql.insert, core.removeMoney, core.addMoney
local phase
local skinWrites, presetWrites, charges, refunds = {}, {}, {}, {}
Kora.sql.single = function(query, params)
    if phase == 'skin' then return coroutine.yield('skin', params[1]) end
    return oldSingle(query, params)
end
Kora.sql.query = function(query, params)
    if not query:find('`outfitname`', 1, true) and phase == 'owned' then
        return coroutine.yield('owned', params[1])
    end
    return oldQuery(query, params)
end
Kora.sql.execute = function(query, params)
    skinWrites[#skinWrites + 1] = params[1]
    local result = oldExecute(query, params)
    if phase == 'refund' then return nil end
    if phase == 'write' then return coroutine.yield('write', params[1]) end
    return result
end
Kora.sql.scalar = function(_, params)
    if phase == 'count' then return coroutine.yield('count', params[1]) end
    return 0
end
Kora.sql.insert = function(_, params)
    presetWrites[#presetWrites + 1] = params[1]
    if phase == 'insert' then return coroutine.yield('insert', params[1]) end
    return 77
end
core.removeMoney = function(_, src, account, amount, reason)
    charges[#charges + 1] = { citizenid = players[src].citizenid, amount = amount, reason = reason }
    players[src].money[account] = players[src].money[account] - amount
    if phase == 'payment' then return coroutine.yield('payment') end
    return true
end
core.addMoney = function(_, src, account, amount)
    refunds[#refunds + 1] = players[src].citizenid
    players[src].money[account] = players[src].money[account] + amount
    if phase == 'refund' then return coroutine.yield('refund') end
    return true
end
local payload = { skin = { components = { ['11'] = { d = 2, t = 0 } } }, saveName = 'Look' }
local owned = { { model = Shared.models.male, skin = payload.skin } }
local cases = {
    { phase = 'skin', result = saved },
    { phase = 'owned', result = {} },
    { phase = 'owned', result = owned },
    { phase = 'write', result = 1 },
    { phase = 'write' }, -- Already-dispatched failed write must not refund a new character.
    { phase = 'count', result = 0 },
    { phase = 'count', result = Config.wardrobe.maxOutfits },
    { phase = 'insert', result = 77 },
    { phase = 'insert' },
}
for _, boundary in ipairs({ 'cancel', 'logout-same', 'logout-different' }) do
    for _, case in ipairs(cases) do
        players[7] = { citizenid = 'first', charinfo = { gender = 0 }, money = { cash = 1000 } }
        start()
        phase = case.phase
        local pending = coroutine.create(function() events['qbclothing:server:confirmSession'](7, payload) end)
        local stage, citizenid = resume(pending)
        H.equal(stage, case.phase)
        H.equal(citizenid, 'first', 'SQL retains the initiating citizen identity')
        phase = nil
        if boundary == 'cancel' then cancel() else emit('QBCore:Server:OnPlayerUnload', 7, 7) end
        if boundary == 'logout-different' then players[7].citizenid = 'replacement' end
        players[7].money.cash = 1000
        start()
        local closed, moved, errors = #closes, #moves, #sessionErrors
        local written, inserted, charged, refunded = #skinWrites, #presetWrites, #charges, #refunds
        resume(pending, case.result)
        H.equal(coroutine.status(pending), 'dead')
        H.equal(#skinWrites, written, 'retired confirmation cannot dispatch another skin write')
        H.equal(#presetWrites, inserted, 'retired confirmation cannot dispatch another preset write')
        H.equal(#charges, charged, 'retired confirmation cannot charge the replacement')
        H.equal(#refunds, refunded, 'retired confirmation cannot credit the replacement')
        H.equal(#sessionErrors, errors, 'retired completion cannot send a replacement fitting an error')
        H.equal(#closes, closed, 'retired confirmation cannot close the replacement')
        H.equal(#moves, moved, 'retired confirmation cannot restore the replacement bucket')
        H.equal(buckets[7], Config.bucket.base + 7)
        H.equal(players[7].money.cash, 1000)
        local opened = #opens
        start()
        H.equal(#opens, opened, 'replacement still owns its server session')
        cancel()
        H.equal(buckets[7], 42)
    end
end

-- Public providers can suspend in their registered player-change subscribers.
local resourceState = GetResourceState
GetResourceState = function(name) return name == 'kora_inventory' and 'started' or 'missing' end
exports.kora_inventory = { addItem = function() return coroutine.yield('item') end }
for _, boundary in ipairs({ 'cancel', 'logout-same', 'logout-different' }) do
    for _, provider in ipairs({ 'payment', 'item', 'refund' }) do
        players[7] = { citizenid = 'first', charinfo = { gender = 0 }, money = { cash = 1000 } }
        start()
        Config.clothingAsItem, phase = provider == 'item', provider
        local pending = coroutine.create(function()
            events['qbclothing:server:confirmSession'](7, { skin = payload.skin })
        end)
        H.equal(resume(pending), provider)
        phase = nil
        if boundary == 'cancel' then cancel() else emit('QBCore:Server:OnPlayerUnload', 7, 7) end
        if boundary == 'logout-different' then players[7].citizenid = 'replacement' end
        players[7].money.cash = 1000
        start()
        local written, closed, moved, errors = #skinWrites, #closes, #moves, #sessionErrors
        resume(pending, true)
        H.equal(coroutine.status(pending), 'dead')
        H.equal(#skinWrites, written, 'retired provider completion cannot dispatch another skin write')
        H.equal(#closes, closed, 'retired provider completion cannot close the replacement')
        H.equal(#moves, moved, 'retired provider completion cannot restore the replacement bucket')
        H.equal(#sessionErrors, errors, 'retired provider completion cannot publish a replacement error')
        H.equal(players[7].money.cash, 1000)
        local opened = #opens
        start()
        H.equal(#opens, opened, 'replacement still owns its session after provider completion')
        cancel()
    end
end
Config.clothingAsItem, GetResourceState, exports.kora_inventory = false, resourceState, nil

-- Without retirement, payment, direct saving, preset saving and returns are unchanged.
players[7] = { citizenid = 'first', charinfo = { gender = 0 }, money = { cash = 1000 } }
start()
local written, inserted, charged, closed = #skinWrites, #presetWrites, #charges, #closes
H.equal(events['qbclothing:server:confirmSession'](7, payload), nil)
H.equal(#skinWrites, written + 1)
H.equal(#presetWrites, inserted + 1)
H.equal(#charges, charged + 1)
H.equal(charges[#charges].amount, Config.services.clothing.prices.tops)
H.equal(charges[#charges].reason, 'qbclothing-purchase')
H.equal(players[7].money.cash, 1000 - Config.services.clothing.prices.tops)
H.equal(#closes, closed + 1)
H.equal(buckets[7], 42)

-- Boxed purchases retain their existing item arguments and before-look reversion.
local oldResourceState = GetResourceState
GetResourceState = function(name) return name == 'kora_inventory' and 'started' or 'missing' end
local grant
exports.kora_inventory = { addItem = function(_, src, name, amount, slot, info, reason)
    grant = { src = src, name = name, amount = amount, slot = slot, info = info, reason = reason }
    return true
end }
Config.clothingAsItem = true
start()
written = #skinWrites
H.equal(events['qbclothing:server:confirmSession'](7, { skin = payload.skin }), nil)
H.equal(#skinWrites, written, 'a boxed purchase still does not overwrite the worn appearance')
H.equal(grant.src, 7)
H.equal(grant.name, Config.clothingItem.name)
H.equal(grant.amount, 1)
H.equal(grant.slot, nil)
H.equal(grant.reason, 'qbclothing-purchase')
H.equal(grant.info.model, Shared.models.male)
H.equal(grant.info.skin.components['11'].d, 2)
H.equal(closes[#closes].payload.revertTo.model, Shared.models.male)
H.equal(buckets[7], 42)
Config.clothingAsItem, GetResourceState, exports.kora_inventory = false, oldResourceState, nil
Kora.sql.single, Kora.sql.query, Kora.sql.execute = oldSingle, oldQuery, oldExecute
Kora.sql.scalar, Kora.sql.insert, core.removeMoney, core.addMoney = oldScalar, oldInsert, oldRemove, oldAdd
players[7].citizenid, players[7].money.cash = 'first', 1000

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
emit('onResourceStop', 7, 'kora_clothing')
H.equal(buckets[7], 42, 'resource stop retains active-session restoration')

-- Population: only the first-character fitting room is emptied, on every entry.
-- Resource stop restores buckets but keeps the session records, so clear them.
emit('QBCore:Server:OnPlayerUnload', 7, 7)
populationCalls = {}
start('firstCharacter')
H.equal(#populationCalls, 1, 'population is written once on entry')
H.equal(populationCalls[1].bucket, Config.bucket.base + 7, 'the personal fitting bucket')
H.equal(populationCalls[1].enabled, false, 'population disabled for the first-character fitting')
emit('QBCore:Server:OnPlayerUnload', 7, 7)
H.equal(buckets[7], 42, 'unload restores the previous bucket')
H.equal(#populationCalls, 1, 'leaving does not touch population')

populationCalls = {}
start('firstCharacter')
emit('onResourceStop', 7, 'kora_clothing')
H.equal(buckets[7], 42, 'resource stop restores the previous bucket')
emit('QBCore:Server:OnPlayerUnload', 7, 7)

populationCalls = {}
start('firstCharacter')
events['qbclothing:server:confirmSession'](7, { skin = {} })
H.equal(buckets[7], 42, 'finishing restores the previous bucket')

-- A reused slot follows the current mode: shops are not emptied, and a bucket
-- left disabled by an earlier first-character fitting is switched back on.
saved = { model = Shared.models.male, skin = {} }
populationCalls = {}
start('wardrobe')
H.equal(#populationCalls, 1)
H.equal(populationCalls[1].enabled, true, 'shop/wardrobe keep ambient population')
cancel()
H.equal(buckets[7], 42)

saved = nil
local was = Config.bucket.disablePopulation
Config.bucket.disablePopulation = false
populationCalls = {}
start('firstCharacter')
H.equal(populationCalls[1].enabled, true, 'disablePopulation = false leaves population on')
H.equal(buckets[7], Config.bucket.base + 7, 'the fitting room bucket is still used')
emit('QBCore:Server:OnPlayerUnload', 7, 7)
H.equal(buckets[7], 42)
Config.bucket.disablePopulation = was

-- A missing native must not break isolation.
local native = SetRoutingBucketPopulationEnabled
SetRoutingBucketPopulationEnabled = nil
start('firstCharacter')
H.equal(buckets[7], Config.bucket.base + 7, 'isolation survives a missing population native')
emit('QBCore:Server:OnPlayerUnload', 7, 7)
SetRoutingBucketPopulationEnabled = native
H.finish()

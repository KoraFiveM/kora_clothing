-- Quick clothing toggles: `/c <part>` takes one item off, a second use puts back
-- exactly what was worn. Config.quickToggle (config.lua) documents every option.
--
-- Purely local and temporary: nothing here is sent to the server or saved, so the
-- saved outfit is always the "put back" state. Per part we remember what was worn
-- (drawable/texture/palette) AND what we set it to; on restore an item that no
-- longer matches what we set was changed by the player meanwhile (menu, outfit,
-- another script), so the stale memory is dropped rather than restored over it.

QuickToggle = QuickToggle or {}

-- partId -> { model = string, components = { [id] = { prev = {d,t,p}, applied = {d,t} } },
--             props = { [id] = { prev = {d,t}, } } }
local removed = {}
local lastUse = 0
local busy = false

local function cfg() return Config.quickToggle or {} end

local function notify(message, kind)
    Kora.notify.send({ title = 'Clothing', message = message, type = kind or 'info' })
end

local function gender(ped)
    local model = GetEntityModel(ped)
    if model == joaat(Shared.models.male) then return 'male', Shared.models.male end
    if model == joaat(Shared.models.female) then return 'female', Shared.models.female end
    return nil
end

local function findPart(word)
    word = tostring(word or ''):lower()
    for _, part in ipairs(cfg().parts or {}) do
        if part.id:lower() == word then return part end
        for _, alias in ipairs(part.aliases or {}) do
            if alias:lower() == word then return part end
        end
    end
end

local function isResetWord(word)
    word = tostring(word or ''):lower()
    for _, w in ipairs(cfg().resetWords or { 'reset', 'all' }) do
        if w:lower() == word then return true end
    end
    return false
end

local function partIds()
    local ids = {}
    for _, part in ipairs(cfg().parts or {}) do ids[#ids + 1] = part.id end
    return ids
end

local function usage()
    local ids = partIds()
    ids[#ids + 1] = (cfg().resetWords or { 'reset' })[1] or 'reset'
    return ('Usage: /%s <%s>'):format(cfg().command or 'c', table.concat(ids, '|'))
end

local function isCuffed()
    if GetResourceState('kora_police') ~= 'started' then return false end
    local ok, cuffed = pcall(function() return exports.kora_police:isHandcuffed() end)
    return ok and cuffed == true
end

---@return string|nil reason the command cannot be used right now
local function blockedReason(ped)
    local c = cfg()
    if QuickToggle.sessionActive and QuickToggle.sessionActive() then
        return 'Close the clothing menu first.'
    end
    if c.allowDead ~= true and IsEntityDead(ped) then return 'You cannot do that right now.' end
    if c.allowCuffed ~= true and isCuffed() then return 'You cannot do that while cuffed.' end
    if c.allowInVehicle ~= true and IsPedInAnyVehicle(ped, false) then return 'You cannot do that in a vehicle.' end
    return nil
end

-- Bounds-checked like applySkin: an out-of-range index faults the game.
local function setComponent(ped, id, d, t, p)
    local drawables = GetNumberOfPedDrawableVariations(ped, id)
    if d < 0 or d >= drawables then return false end
    local textures = GetNumberOfPedTextureVariations(ped, id, d)
    if t < 0 or t >= textures then t = 0 end
    SetPedComponentVariation(ped, id, d, t, p or 0)
    return true
end

local function setProp(ped, id, d, t)
    if d < 0 or d >= GetNumberOfPedPropDrawableVariations(ped, id) then return false end
    local textures = GetNumberOfPedPropTextureVariations(ped, id, d)
    if t < 0 or t >= textures then t = 0 end
    SetPedPropIndex(ped, id, d, t, true)
    return true
end

---Takes the part off. Returns 'removed', 'nothing' (already bare) or 'invalid'.
local function removePart(ped, part, g, model)
    local entries = part[g] or {}
    local record = { model = model, components = {}, props = {} }
    local touched = false

    for _, entry in ipairs(entries) do
        local id = tonumber(entry.id)
        local d, t = tonumber(entry.d), tonumber(entry.t) or 0
        if id and d then
            local cd, ct = GetPedDrawableVariation(ped, id), GetPedTextureVariation(ped, id)
            if cd ~= d then
                local prev = { d = cd, t = ct, p = GetPedPaletteVariation(ped, id) }
                if setComponent(ped, id, d, t, 0) then
                    record.components[id] = {
                        prev = prev,
                        applied = { d = GetPedDrawableVariation(ped, id), t = GetPedTextureVariation(ped, id) },
                    }
                    touched = true
                end
            end
        end
    end

    for _, id in ipairs(part.props or {}) do
        local d = GetPedPropIndex(ped, id)
        if d >= 0 then
            record.props[id] = { prev = { d = d, t = GetPedPropTextureIndex(ped, id) } }
            ClearPedProp(ped, id)
            touched = true
        end
    end

    if not touched then return 'nothing' end
    removed[part.id] = record
    return 'removed'
end

---Puts the part back. Returns 'restored', 'stale' (player changed it meanwhile) or 'none'.
local function restorePart(ped, part, model)
    local record = removed[part.id]
    removed[part.id] = nil
    if not record then return 'none' end
    if record.model ~= model then return 'stale' end

    local restored = false
    for id, entry in pairs(record.components) do
        if GetPedDrawableVariation(ped, id) == entry.applied.d and GetPedTextureVariation(ped, id) == entry.applied.t then
            restored = setComponent(ped, id, entry.prev.d, entry.prev.t, entry.prev.p) or restored
        end
    end
    for id, entry in pairs(record.props) do
        if GetPedPropIndex(ped, id) < 0 then
            restored = setProp(ped, id, entry.prev.d, entry.prev.t) or restored
        end
    end
    return restored and 'restored' or 'stale'
end

local function playAnim(ped, part)
    local c = cfg()
    if c.animations ~= true or not part.animDict or part.animDict == '' then return end
    if IsPedInAnyVehicle(ped, false) and c.animationsInVehicle ~= true then return end
    if not DoesAnimDictExist(part.animDict) then return end
    RequestAnimDict(part.animDict)
    local waited = 0
    while not HasAnimDictLoaded(part.animDict) and waited < 1000 do Wait(25); waited = waited + 25 end
    if not HasAnimDictLoaded(part.animDict) then return end
    local ms = tonumber(part.animMs) or 1500
    TaskPlayAnim(ped, part.animDict, part.animClip, 8.0, -8.0, ms, 48, 0.0, false, false, false)
    Wait(math.floor(ms * 0.5))
end

local function toggleVisor(ped, g)
    local d = GetPedPropIndex(ped, 0)
    if d < 0 then notify('You are not wearing a hat or helmet.', 'error'); return end
    local pairs_ = (cfg().visor or {})[g] or {}
    local other = pairs_[d]
    if other == nil then
        for from, to in pairs(pairs_) do
            if to == d then other = from; break end
        end
    end
    if other == nil then notify('This hat has no visor to flip.', 'error'); return end
    if setProp(ped, 0, other, GetPedPropTextureIndex(ped, 0)) then
        removed.hat = nil -- a remembered hat would no longer match the helmet we just changed
        notify('Visor toggled.', 'success')
    else
        notify('This hat has no visor to flip.', 'error')
    end
end

---Puts back everything that is still removed; the result is a count of restored parts.
function QuickToggle.restoreAll()
    local ped = PlayerPedId()
    local _, model = gender(ped)
    local count = 0
    for _, part in ipairs(cfg().parts or {}) do
        if removed[part.id] and restorePart(ped, part, model) == 'restored' then count = count + 1 end
    end
    removed = {}
    return count
end

---Forgets everything without touching the ped (the ped was just re-dressed from the saved skin).
function QuickToggle.forget()
    removed = {}
end

---@param word string|nil
function QuickToggle.run(word)
    local c = cfg()
    if c.enabled ~= true then return end
    if word == nil or word == '' then notify(usage(), 'info'); return end

    local resetting = isResetWord(word)
    local part = not resetting and findPart(word) or nil
    if not resetting and not part then notify(usage(), 'error'); return end

    local ped = PlayerPedId()
    local reason = blockedReason(ped)
    if reason then notify(reason, 'error'); return end

    local g, model = gender(ped)
    if not g then notify('Quick clothing toggles only work on the freemode character.', 'error'); return end

    local now = GetGameTimer()
    if busy or (tonumber(c.cooldownMs) or 0) > 0 and now - lastUse < c.cooldownMs then return end
    busy, lastUse = true, now

    if resetting then
        local count = QuickToggle.restoreAll()
        notify(count > 0 and 'Clothes put back on.' or 'Nothing to put back.', count > 0 and 'success' or 'info')
        busy = false
        return
    end

    local ok, err = pcall(function()
        if part.visor then
            toggleVisor(ped, g)
            return
        end
        if removed[part.id] then
            playAnim(ped, part)
            ped = PlayerPedId()
            local result = restorePart(ped, part, model)
            if result == 'restored' then
                notify(('%s put back on.'):format(part.label or part.id), 'success')
                return
            end
            -- The player changed it meanwhile: the memory is gone, so fall through
            -- and treat this use as a fresh removal of whatever is worn now.
        end
        playAnim(ped, part)
        ped = PlayerPedId()
        local result = removePart(ped, part, g, model)
        if result == 'removed' then
            notify(('%s taken off. Use it again to put it back.'):format(part.label or part.id), 'success')
        elseif result == 'nothing' then
            notify(('You are not wearing anything there (%s).'):format(part.label or part.id), 'info')
        end
    end)
    busy = false
    if not ok then print(('[kora_clothing] quick toggle failed: %s'):format(tostring(err))) end
end

-- --- registration ---

local registeredCommand

local function suggestion()
    local c = cfg()
    if c.enabled ~= true or c.chatSuggestion ~= true or not registeredCommand then return end
    local ids = partIds()
    ids[#ids + 1] = table.concat(c.resetWords or { 'reset' }, '/')
    TriggerEvent('chat:addSuggestion', '/' .. registeredCommand, 'Take off / put back a clothing item', {
        { name = 'part', help = table.concat(ids, ', ') },
    })
end

local function register()
    local c = cfg()
    if c.enabled ~= true or type(c.command) ~= 'string' or c.command == '' then return end
    registeredCommand = c.command
    RegisterCommand(registeredCommand, function(_, args) QuickToggle.run(args[1]) end, false)
    suggestion()
end

AddEventHandler('chat:init', suggestion)
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'chat' then suggestion() end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not registeredCommand then return end
    TriggerEvent('chat:removeSuggestion', '/' .. registeredCommand)
end)

register()

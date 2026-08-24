-- qbclothing client: NUI owner, ped/camera control while a fitting-room
-- session is open, shop-ped targets, and the real qb-clothing client wire
-- protocol for third-party compat. Owns its own NUI frame (own `ui_page`), so
-- this talks to it with the raw natives directly -- QB.nui.* would dispatch
-- into qblib's own resource VM/frame instead of this one.

local activeSession -- { mode, service, mandatory, shopLabel, tattoos } while the NUI is open, else nil
local disableControlsThread = false
local previewTattoos = {}

local function notify(message, kind)
    QB.notify.send({ title = 'Clothing', message = message, type = kind or 'info' })
end

-- --- ped appearance helpers ---

local function sanitiseTattoos(model, tattoos)
    local selected, seen = {}, {}
    for _, id in ipairs(type(tattoos) == 'table' and tattoos or {}) do
        if not seen[id] and Shared.tattooById(model, id) then
            seen[id] = true
            selected[#selected + 1] = id
        end
    end
    return selected
end

local function applyTattoos(ped, model, tattoos)
    previewTattoos = sanitiseTattoos(model, tattoos)
    ClearPedDecorations(ped)
    for _, id in ipairs(previewTattoos) do
        local tattoo = Shared.tattooById(model, id)
        if tattoo then AddPedDecorationFromHashes(ped, GetHashKey(tattoo.collection), GetHashKey(tattoo.overlay)) end
    end
end

local function applySkin(ped, skin, model)
    skin = skin or {}
    local components = skin.components or {}
    for id in pairs(Shared.components) do
        local entry = components[tostring(id)]
        if entry then
            SetPedComponentVariation(ped, id, entry.d or 0, entry.t or 0, 0)
        end
    end

    local props = skin.props or {}
    for id in pairs(Shared.props) do
        local entry = props[tostring(id)]
        if entry and entry.d and entry.d >= 0 then
            SetPedPropIndex(ped, id, entry.d, entry.t or 0, true)
        else
            ClearPedProp(ped, id)
        end
    end
    applyTattoos(ped, model, skin.tattoos)
end

local function currentSkinSnapshot(ped)
    local skin = { components = {}, props = {}, tattoos = previewTattoos }
    for id in pairs(Shared.components) do
        skin.components[tostring(id)] = { d = GetPedDrawableVariation(ped, id), t = GetPedTextureVariation(ped, id) }
    end
    for id in pairs(Shared.props) do
        local drawable = GetPedPropIndex(ped, id)
        if drawable >= 0 then
            skin.props[tostring(id)] = { d = drawable, t = GetPedPropTextureIndex(ped, id) }
        end
    end
    return skin
end

local function buildCategoryPayload(ped, service)
    local categories = {}
    local policy = Config.services[service] or Config.services.clothing
    local function allowed(ids, id)
        if policy.all then return true end
        for _, candidate in ipairs(ids or {}) do if candidate == id then return true end end
        return false
    end
    for id, meta in pairs(Shared.components) do
        if allowed(policy.components, id) then
            local drawable = GetPedDrawableVariation(ped, id)
            categories[#categories + 1] = {
            kind = 'component',
            id = id,
            label = meta.label,
            category = meta.category,
            drawable = drawable,
            texture = GetPedTextureVariation(ped, id),
            drawableCount = GetNumberOfPedDrawableVariations(ped, id),
            textureCount = GetNumberOfPedTextureVariations(ped, id, drawable),
            }
        end
    end
    for id, meta in pairs(Shared.props) do
        if allowed(policy.props, id) then
            local drawable = GetPedPropIndex(ped, id)
            categories[#categories + 1] = {
            kind = 'prop',
            id = id,
            label = meta.label,
            category = meta.category,
            clearable = meta.clearable,
            drawable = drawable,
            texture = drawable >= 0 and GetPedPropTextureIndex(ped, id) or 0,
            drawableCount = GetNumberOfPedPropDrawableVariations(ped, id),
            textureCount = drawable >= 0 and GetNumberOfPedPropTextureVariations(ped, id, drawable) or 0,
            }
        end
    end
    return categories
end

-- Reads the model back off the live ped rather than trusting whatever was
-- last requested -- the source of truth for what to report to the NUI/server,
-- since a requested model swap can fail to stream in time (see applyModel).
local function currentModelName(ped)
    return GetEntityModel(ped) == GetHashKey(Shared.models.female) and Shared.models.female or Shared.models.male
end

local function applyModel(model, skin)
    local ped = PlayerPedId()
    local hash = GetHashKey(model)
    if GetEntityModel(ped) ~= hash then
        RequestModel(hash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
        if not HasModelLoaded(hash) then return false end
        SetPlayerModel(PlayerId(), hash)
        SetModelAsNoLongerNeeded(hash)
        ped = PlayerPedId()
        SetPedDefaultComponentVariation(ped)
    end
    applySkin(ped, skin, model)
    return true
end

-- --- movement lock while the fitting room is open ---

local function startControlLock()
    disableControlsThread = true
    CreateThread(function()
        while disableControlsThread do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)  -- LookLeftRight (camera drag still usable by our own zone buttons, not free mouse-look)
            EnableControlAction(0, 2, true)  -- LookUpDown
            EnableControlAction(0, 249, true) -- push-to-talk, harmless to leave enabled
            Wait(0)
        end
    end)
end

local function stopControlLock()
    disableControlsThread = false
end

-- --- session lifecycle ---

RegisterNetEvent('qbclothing:client:openSession', function(payload)
    if type(payload) ~= 'table' then return end

    -- Freeze AFTER the model swap, not before: SetPlayerModel (inside
    -- applyModel) destroys the old ped entity and creates a new one, so a
    -- freeze applied to the pre-swap handle would not carry over.
    applyModel(payload.model, payload.skin)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)

    activeSession = {
        mode = payload.mode,
        service = payload.service or 'clothing',
        mandatory = payload.mandatory == true,
        shopLabel = payload.shopLabel,
    }

    startControlLock()
    Camera.start(ped)

    SendNUIMessage({ action = 'qbclothing:nui:theme', data = QB.theme.tokens() })
    SendNUIMessage({
        action = 'qbclothing:nui:open',
        data = {
            mode = payload.mode,
            service = activeSession.service,
            free = payload.free == true,
            mandatory = activeSession.mandatory,
            shopLabel = payload.shopLabel,
            -- Read back off the live ped, not echoed from the request --
            -- if the requested model failed to stream in time, this must
            -- reflect what the player is actually wearing, not what was asked for.
            model = currentModelName(ped),
            categories = buildCategoryPayload(ped, activeSession.service),
            tattoos = payload.tattoos or {},
            selectedTattoos = previewTattoos,
            outfits = payload.outfits or {},
            money = payload.money,
            prices = payload.prices,
            currency = payload.currency,
        },
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('qbclothing:client:outfitsUpdated', function(outfits)
    if not activeSession then return end
    SendNUIMessage({ action = 'qbclothing:nui:outfits', data = outfits or {} })
end)

RegisterNetEvent('qbclothing:client:sessionError', function(message)
    if activeSession then
        SendNUIMessage({ action = 'qbclothing:nui:error', data = { message = message } })
    end
    notify(message, 'error')
end)

RegisterNetEvent('qbclothing:client:closeSession', function(result)
    if not activeSession then return end
    Camera.stop()
    stopControlLock()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'qbclothing:nui:close' })
    FreezeEntityPosition(PlayerPedId(), false)

    if result and result.ok and not result.cancelled then
        if result.revertTo then
            -- Config.clothingAsItem: the purchase was boxed as an inventory
            -- item, not worn -- the live ped was only ever a try-on preview,
            -- so revert it to whatever was actually equipped before this
            -- session started.
            applyModel(result.revertTo.model, result.revertTo.skin)
            notify('Outfit added to your inventory.', 'success')
        else
            notify('Outfit updated.', 'success')
        end
    end
    activeSession = nil
end)

-- --- NUI callbacks ---

RegisterNUICallback('qbclothing:nui:setVariation', function(data, cb)
    if not activeSession or type(data) ~= 'table' then cb({ ok = false }); return end
    local ped = PlayerPedId()
    local id = tonumber(data.id)

    if data.kind == 'component' and id and Shared.components[id] then
        local drawable = math.max(0, tonumber(data.drawable) or 0)
        SetPedComponentVariation(ped, id, drawable, math.max(0, tonumber(data.texture) or 0), 0)
        cb({
            ok = true,
            drawable = drawable,
            texture = GetPedTextureVariation(ped, id),
            drawableCount = GetNumberOfPedDrawableVariations(ped, id),
            textureCount = GetNumberOfPedTextureVariations(ped, id, drawable),
        })
    elseif data.kind == 'prop' and id and Shared.props[id] then
        local drawable = tonumber(data.drawable) or -1
        if drawable < 0 then
            ClearPedProp(ped, id)
        else
            SetPedPropIndex(ped, id, drawable, math.max(0, tonumber(data.texture) or 0), true)
        end
        cb({
            ok = true,
            drawable = drawable,
            texture = drawable >= 0 and GetPedPropTextureIndex(ped, id) or 0,
            drawableCount = GetNumberOfPedPropDrawableVariations(ped, id),
            textureCount = drawable >= 0 and GetNumberOfPedPropTextureVariations(ped, id, drawable) or 0,
        })
    else
        cb({ ok = false })
    end
end)

RegisterNUICallback('qbclothing:nui:setTattoos', function(data, cb)
    if not activeSession or type(data) ~= 'table' then cb({ ok = false }); return end
    local policy = Config.services[activeSession.service] or {}
    if not policy.tattoos then cb({ ok = false }); return end
    local ped = PlayerPedId()
    applyTattoos(ped, currentModelName(ped), data.tattoos)
    cb({ ok = true, tattoos = previewTattoos })
end)

RegisterNUICallback('qbclothing:nui:camera', function(data, cb)
    if type(data) == 'table' and data.zone then Camera.setZone(data.zone) end
    cb({})
end)

RegisterNUICallback('qbclothing:nui:rotate', function(data, cb)
    if type(data) == 'table' then Camera.rotate(data.deltaDeg) end
    cb({})
end)

RegisterNUICallback('qbclothing:nui:loadOutfit', function(data, cb)
    if not activeSession or type(data) ~= 'table' then cb({ ok = false }); return end
    local model, skin = QB.callback.trigger('qbclothing:server:getOutfitSkin', tonumber(data.id))
    if not model then cb({ ok = false }); return end
    applyModel(model, skin)
    local ped = PlayerPedId()
    cb({ ok = true, model = currentModelName(ped), categories = buildCategoryPayload(ped, activeSession.service), selectedTattoos = previewTattoos })
end)

RegisterNUICallback('qbclothing:nui:deleteOutfit', function(data, cb)
    if activeSession and type(data) == 'table' and data.id then
        TriggerServerEvent('qbclothing:server:deleteOutfit', tonumber(data.id))
    end
    cb({})
end)

RegisterNUICallback('qbclothing:nui:confirm', function(data, cb)
    if not activeSession then cb({ ok = false }); return end
    local ped = PlayerPedId()
    TriggerServerEvent('qbclothing:server:confirmSession', {
        model = currentModelName(ped),
        skin = currentSkinSnapshot(ped),
        saveName = type(data) == 'table' and data.saveName or nil,
    })
    cb({ ok = true })
end)

RegisterNUICallback('qbclothing:nui:cancel', function(_, cb)
    if not activeSession or activeSession.mandatory then cb({ ok = false }); return end
    TriggerServerEvent('qbclothing:server:cancelSession')
    cb({ ok = true })
end)

-- --- open triggers ---

local function openSession(mode, extra)
    if activeSession then return end
    TriggerServerEvent('qbclothing:server:requestSession', mode, extra)
end

-- Re-applies the player's last-saved appearance on every login (not just
-- character creation) -- without this, a purchased/saved outfit would only
-- ever be visible for the remainder of the session it was bought in. Fires
-- for a brand-new character too (QBCore:Client:OnPlayerLoaded is the same
-- adopt() path createCharacter uses), where it's simply a no-op since
-- qb-clothing:server:getSkin has nothing saved yet.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        local model, skin = QB.callback.trigger('qb-clothing:server:getSkin')
        -- The callback trigger is a network round trip -- a fitting-room
        -- session can legitimately open while it's in flight (e.g. another
        -- resource calls exports.qbclothing:OpenWardrobe() right after
        -- login). Applying a late-arriving saved skin at that point would
        -- silently clobber whatever the player is currently trying on.
        if not model or activeSession then return end
        applyModel(model, skin)
    end)
end)

-- Config.clothingAsItem: fired by the server when a `qbclothing_outfit` item
-- is used from inventory. Never applied while a fitting-room session is open
-- -- that would clobber whatever the player is currently trying on.
RegisterNetEvent('qbclothing:client:wearItem', function(model, skin)
    if activeSession then return end
    applyModel(model, skin)
end)

-- The unambiguous "a character was just created" signal in this codebase:
-- qbcore's compat (qb-multicharacter:server:createCharacter handler) fires
-- this client event ONLY on successful character creation, never on an
-- existing-character login (that path goes through qb-spawn instead). Waiting
-- for the ped to actually be alive rather than relying on registration order
-- against qbmultichar's own handler keeps this robust regardless of resource
-- start order.
RegisterNetEvent('qb-multicharacter:client:closeNUIdefault', function()
    CreateThread(function()
        local timeout = GetGameTimer() + 15000
        while (not NetworkIsPlayerActive(PlayerId()) or IsEntityDead(PlayerPedId())) and GetGameTimer() < timeout do
            Wait(50)
        end
        Wait(250) -- let qbmultichar's own handler finish its teleport/resurrect/fade-in first
        TriggerEvent('qb-clothing:client:CreateFirstCharacter')
    end)
end)

-- --- real qb-clothing client wire protocol (third-party compat) ---

RegisterNetEvent('qb-clothing:client:CreateFirstCharacter', function()
    openSession('firstCharacter')
end)

RegisterNetEvent('qb-clothing:client:openMenu', function(shopType)
    openSession('shop', type(shopType) == 'table' and shopType or { shopId = tonumber(shopType) or 1 })
end)

-- Used by qbadmin's self-service clothing entry.  Keeping the nearest-shop
-- selection inside qbclothing means external callers never have to duplicate
-- this resource's shop ordering; the server still performs the authoritative
-- distance check when it receives requestSession('shop', index).
RegisterNetEvent('qbclothing:client:openNearestShop', function()
    local coords = GetEntityCoords(PlayerPedId())
    local nearestIndex, nearestDistance
    for index, shop in ipairs(Config.shops) do
        if (shop.service or 'clothing') == 'clothing' then
            local distance = #(coords - shop.coords)
            if not nearestDistance or distance < nearestDistance then
                nearestIndex, nearestDistance = index, distance
            end
        end
    end

    if not nearestIndex or nearestDistance > Config.interactDistance then
        QB.notify.send({ type = 'error', message = 'You are not near a clothing shop' })
        return
    end
    openSession('shop', { shopId = nearestIndex })
end)

RegisterNetEvent('qb-clothing:client:openOutfitMenu', function()
    openSession('wardrobe')
end)

RegisterNetEvent('qb-clothing:client:loadOutfit', function(outfit)
    if type(outfit) ~= 'table' then return end
    applyModel(outfit.model or Shared.models.male, outfit.skin)
end)

-- Public modern form: exports.qbclothing:OpenClothingRoom({ shopId = 1 }).
-- The numeric form remains for existing qb-clothing consumers.
exports('OpenClothingRoom', function(options)
    openSession('shop', type(options) == 'table' and options or { shopId = tonumber(options) or 1 })
end)
exports('OpenWardrobe', function() openSession('wardrobe') end)
exports('IsClothingMenuOpen', function() return activeSession ~= nil end)
exports('GetPedModels', function() return Shared.models end)

-- --- shop peds ---

CreateThread(function()
    for index, shop in ipairs(Config.shops) do
        local ped = QB.entities.create(shop.ped, shop.coords, { freeze = true, blockNonTempEvents = true })
        if ped then
            exports.qbtarget:addEntity(ped, {
                {
                    label = ('Open %s'):format(shop.label),
                    icon = 'Shirt',
                    distance = Config.interactDistance,
                    onSelect = function() openSession('shop', { shopId = index }) end,
                },
            }, Config.interactDistance)
        end

        if shop.blip and shop.blip.enabled then
            QB.blips.create(shop.coords, shop.blip)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if activeSession then
        Camera.stop()
        stopControlLock()
        SetNuiFocus(false, false)
        FreezeEntityPosition(PlayerPedId(), false)
    end
end)

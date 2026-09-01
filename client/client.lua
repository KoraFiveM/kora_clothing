-- qbclothing client: NUI owner, ped/camera control while a fitting-room
-- session is open, shop-ped targets, and the real qb-clothing client wire
-- protocol for third-party compat. Owns its own NUI frame (own `ui_page`), so
-- this talks to it with the raw natives directly -- QB.nui.* would dispatch
-- into qblib's own resource VM/frame instead of this one.

local activeSession -- { mode, service, mandatory, shopLabel, tattoos } while the NUI is open, else nil
local disableControlsThread = false
local previewTattoos = {}

-- Session-local, never sent to the server or persisted: what a tattoo/barber/
-- hairdresser session temporarily overrode (bare skin for tattoos, hat/mask
-- removed for hair work) so it can be put back exactly as found on close.
-- { components = { [id] = { d, t } }, props = { [id] = { d, t } | false } }
local temporaryOverride = nil

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

-- SetPedComponentVariation/SetPedPropIndex fault inside the game's own
-- executable (not a catchable Lua error) when given a drawable/texture index
-- the CURRENT model/slot doesn't actually have -- server-side sanitiseSkin
-- only clamps to a generous [-1, 999] "not garbage" range (see its own
-- comment: the true per-model/per-slot cap can't be known server-side), and
-- `skin` here can also arrive from an external export/event caller rather than
-- the sanitized server callbacks. So every index
-- gets bounds-checked here, against the SAME live GetNumberOfPed*Variations
-- queries buildCategoryPayload already uses to build the NUI list, right
-- before the native call that would otherwise crash on it.
local function applySkin(ped, skin, model)
    skin = skin or {}
    local components = skin.components or {}
    for id in pairs(Shared.components) do
        local entry = components[tostring(id)]
        if entry then
            local drawableCount = GetNumberOfPedDrawableVariations(ped, id)
            if drawableCount > 0 then
                local drawable = entry.d or 0
                if type(drawable) ~= 'number' or drawable < 0 or drawable >= drawableCount then drawable = 0 end
                local textureCount = GetNumberOfPedTextureVariations(ped, id, drawable)
                local texture = entry.t or 0
                if textureCount <= 0 or type(texture) ~= 'number' or texture < 0 or texture >= textureCount then
                    texture = 0
                end
                SetPedComponentVariation(ped, id, drawable, texture, 0)
            end
        end
    end

    local props = skin.props or {}
    for id in pairs(Shared.props) do
        local entry = props[tostring(id)]
        local drawable = entry and entry.d
        if entry and type(drawable) == 'number' and drawable >= 0
            and drawable < GetNumberOfPedPropDrawableVariations(ped, id) then
            local textureCount = GetNumberOfPedPropTextureVariations(ped, id, drawable)
            local texture = entry.t or 0
            if textureCount <= 0 or type(texture) ~= 'number' or texture < 0 or texture >= textureCount then
                texture = 0
            end
            SetPedPropIndex(ped, id, drawable, texture, true)
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

-- --- temporary strip for tattoo/barber/hairdresser sessions ---

---@return table|false  -- { d, t } if a hat was worn, else false (nothing to restore)
local function stripHat(ped)
    local drawable = GetPedPropIndex(ped, 0)
    local saved = drawable >= 0 and { d = drawable, t = GetPedPropTextureIndex(ped, 0) } or false
    ClearPedProp(ped, 0)
    return saved
end

---Bares whatever this service's own work needs to actually be seen --
---underwear for a tattoo session (every catalogue group would otherwise sit
---under clothing), hat/mask removed for barber/hairdresser (both cover the
---hair being edited). Captures the pre-override state into
---`temporaryOverride` first so `restoreTemporaryOverride` can put it back
---unconditionally, regardless of what (if anything) changed during the
---session -- a tattoo/barber/hairdresser session's own component/prop
---whitelist is empty or hair-only (Config.services), so nothing here can be
---legitimately re-edited by the player during the session anyway.
---@param ped integer
---@param service string
---@param model string
local function applyTemporaryStrip(ped, service, model)
    temporaryOverride = nil

    if service == 'tattoo' then
        local strip = Config.tattooStrip[Shared.modelGender(model)]
        if not strip then return end

        local override = { components = {}, props = { [0] = stripHat(ped) } }
        for id, variation in pairs(strip) do
            override.components[id] = { d = GetPedDrawableVariation(ped, id), t = GetPedTextureVariation(ped, id) }
            SetPedComponentVariation(ped, id, variation.d, variation.t, 0)
        end
        temporaryOverride = override
    elseif service == 'barber' or service == 'hairdresser' then
        temporaryOverride = {
            components = { [1] = { d = GetPedDrawableVariation(ped, 1), t = GetPedTextureVariation(ped, 1) } },
            props = { [0] = stripHat(ped) },
        }
        SetPedComponentVariation(ped, 1, 0, 0, 0) -- mask: none
    end
end

local function restoreTemporaryOverride(ped)
    if not temporaryOverride then return end
    local override = temporaryOverride
    temporaryOverride = nil

    for id, variation in pairs(override.components) do
        SetPedComponentVariation(ped, id, variation.d, variation.t, 0)
    end
    for id, variation in pairs(override.props) do
        if variation then
            SetPedPropIndex(ped, id, variation.d, variation.t, true)
        else
            ClearPedProp(ped, id)
        end
    end
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

    -- After the real skin is applied, not before -- this has to override
    -- what the player actually walked in wearing, not whatever the ped's
    -- default/previous state happened to be.
    applyTemporaryStrip(ped, activeSession.service, currentModelName(ped))

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
            -- session started. That already restores everything a temporary
            -- strip touched (hat/mask/underwear), so there's nothing left
            -- for restoreTemporaryOverride to do here.
            temporaryOverride = nil
            applyModel(result.revertTo.model, result.revertTo.skin)
            notify('Outfit added to your inventory.', 'success')
        else
            restoreTemporaryOverride(PlayerPedId())
            notify('Outfit updated.', 'success')
        end
    else
        -- Cancelled, or the session ended some other way -- still put back
        -- whatever a tattoo/barber/hairdresser strip removed.
        restoreTemporaryOverride(PlayerPedId())
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

-- These four fire the tokenised QB.events gateway (server/server.lua) rather
-- than a raw TriggerServerEvent -- trigger() can fail if the connect-time
-- handshake hasn't landed yet (10s timeout), which the existing sessionError
-- display already handles, so a failure here is surfaced the same way any
-- other server-side rejection of these actions already is.
local function triggerOrError(name, ...)
    local ok, err = QB.events.trigger(name, ...)
    if not ok then TriggerEvent('qbclothing:client:sessionError', err) end
end

RegisterNUICallback('qbclothing:nui:deleteOutfit', function(data, cb)
    if activeSession and type(data) == 'table' and data.id then
        triggerOrError('qbclothing:server:deleteOutfit', tonumber(data.id))
    end
    cb({})
end)

RegisterNUICallback('qbclothing:nui:confirm', function(data, cb)
    if not activeSession then cb({ ok = false }); return end
    local ped = PlayerPedId()
    triggerOrError('qbclothing:server:confirmSession', {
        model = currentModelName(ped),
        skin = currentSkinSnapshot(ped),
        saveName = type(data) == 'table' and data.saveName or nil,
    })
    cb({ ok = true })
end)

RegisterNUICallback('qbclothing:nui:cancel', function(_, cb)
    if not activeSession or activeSession.mandatory then cb({ ok = false }); return end
    triggerOrError('qbclothing:server:cancelSession')
    cb({ ok = true })
end)

-- --- open triggers ---

local function openSession(mode, extra)
    if activeSession then return end
    triggerOrError('qbclothing:server:requestSession', mode, extra)
end

-- Re-applies the player's last-saved appearance on every login (not just
-- character creation) -- without this, a purchased/saved outfit would only
-- ever be visible for the remainder of the session it was bought in. Fires
-- for a brand-new character too (QBCore:Client:OnPlayerLoaded is the same
-- adopt() path createCharacter uses), where it's simply a no-op since
-- qb-clothing:server:getSkin has nothing saved yet.
--
-- Bumped once per call and captured as `generation`: the callback trigger
-- below is a network round trip, so two calls can legitimately be in flight
-- at once (a real fresh login fires BOTH this event and the state-bag
-- reconcile below in close succession). Only the call whose generation is
-- still current when its answer arrives actually applies the skin, so the
-- player doesn't get the same (or a stale) skin applied twice. Mirrors
-- qbhud's client/bridge/qbcore.lua loginGeneration pattern.
local skinApplyGeneration = 0

local function applySavedSkin()
    skinApplyGeneration = skinApplyGeneration + 1
    local generation = skinApplyGeneration

    CreateThread(function()
        -- pcall'd: QB.callback.trigger is a cross-resource call into qblib,
        -- which can error if qblib is mid-restart at the same moment (e.g.
        -- this resource restarting alongside its dependencies). An uncaught
        -- error here would otherwise silently kill this CreateThread body.
        local ok, model, skin = pcall(function() return QB.callback.trigger('qb-clothing:server:getSkin') end)
        if not ok then return end
        if generation ~= skinApplyGeneration then return end

        -- The callback trigger is a network round trip -- a fitting-room
        -- session can legitimately open while it's in flight (e.g. another
        -- resource calls exports.qbclothing:OpenWardrobe() right after
        -- login). Applying a late-arriving saved skin at that point would
        -- silently clobber whatever the player is currently trying on.
        if not model or activeSession then return end
        applyModel(model, skin)
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', applySavedSkin)

-- Additional path for "this resource just restarted while a player was
-- already logged in" (e.g. `ensure qbclothing` mid-session): the legacy
-- OnPlayerLoaded event above does NOT re-fire on a resource restart, so
-- without this a restarted qbclothing leaves the player's saved skin
-- un-applied until they relog. Mirrors qbhud's client/bridge/qbcore.lua --
-- watch the server-owned login state bag directly rather than the legacy
-- lifecycle event, and reconcile immediately at chunk load to cover the
-- already-logged-in case, since a bag-change handler only observes future
-- transitions.
local CLOTHING_LOGIN_STATE = 'qbcore:loggedIn'

local function reconcileClothingLogin(value)
    if value == true then applySavedSkin() end
end

local clothingLocalPlayerBag = ('player:%s'):format(GetPlayerServerId(PlayerId()))
AddStateBagChangeHandler(CLOTHING_LOGIN_STATE, clothingLocalPlayerBag, function(_, _, value)
    reconcileClothingLogin(value == true)
end)

reconcileClothingLogin(LocalPlayer.state[CLOTHING_LOGIN_STATE] == true)

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
        -- qbmultichar uses this legacy signal to open the mandatory cinematic
        -- spawn carousel for a new character. Do not put the first-character
        -- clothing UI on top of it; the server-owned mode clears only after
        -- camera, bucket, focus, ped, and NUI cleanup is complete. On servers
        -- without qbmultichar the key is nil and this remains the old path.
        -- Truthiness, not `~= nil`: a cleared mode is `false` (qbmultichar
        -- cannot publish the clear as a nil deletion -- see its writeMode).
        while LocalPlayer.state['qbmultichar:mode'] do Wait(50) end
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
RegisterNetEvent('qbclothing:client:openNearestShop', function(service)
    service = service or 'clothing'
    local coords = GetEntityCoords(PlayerPedId())
    local nearestIndex, nearestDistance
    for index, shop in ipairs(Config.shops) do
        if (shop.service or 'clothing') == service then
            -- shop.coords is a vector4 (heading in .w); vector3 - vector4 is
            -- an unsupported operation, so drop to the vector3 component set.
            local shopCoords = vector3(shop.coords.x, shop.coords.y, shop.coords.z)
            local distance = #(coords - shopCoords)
            if not nearestDistance or distance < nearestDistance then
                nearestIndex, nearestDistance = index, distance
            end
        end
    end

    -- Match the server's authoritative tolerance exactly.  The extra metre
    -- accommodates ped/zone placement while the server still performs the
    -- final coordinate check before it creates a session.
    if not nearestIndex or nearestDistance > (Config.interactDistance + 1.0) then
        QB.notify.send({ type = 'error', message = ('You are not near a %s shop'):format(service) })
        return
    end
    openSession('shop', { shopId = nearestIndex })
end)

RegisterNetEvent('qb-clothing:client:openOutfitMenu', function()
    openSession('wardrobe')
end)

-- Admin-only combined session: clothing + hair + tattoos in one sitting, free
-- and with no shop/model restrictions (mirrors the character-creation
-- service policy). Permission is re-checked server-side in requestSession --
-- this event is just the trigger.
RegisterNetEvent('qbclothing:client:openAdminSession', function()
    openSession('admin')
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
-- Applies this resource's canonical component/prop/tattoo schema to an
-- already-created ped. Character selectors use a local, non-networked clone,
-- so replacing PlayerPedId() (applyModel's job) would be the wrong operation.
exports('ApplyAppearanceToPed', function(ped, model, skin)
    if type(ped) ~= 'number' or ped == 0 or not DoesEntityExist(ped) then
        return false, 'invalid ped'
    end
    if not Shared.isFreemodeModel(model) or GetEntityModel(ped) ~= GetHashKey(model) then
        return false, 'ped model does not match appearance model'
    end
    applySkin(ped, skin, model)
    return true
end)

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

-- Deliberately absent in production. Same pattern as qbtarget's
-- Config.target.testMode -> Target._testRuntime: lets the standalone smoke
-- suite exercise applySkin's index bounds-checking without a running client.
if Config.testMode then
    QBClothing = QBClothing or {}
    QBClothing._testRuntime = { applySkin = applySkin }
end

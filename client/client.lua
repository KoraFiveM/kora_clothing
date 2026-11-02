-- kora_clothing client: NUI owner, ped/camera control while a fitting-room
-- session is open, shop target zones, and the real qb-clothing client wire
-- protocol for third-party compat. Owns its own NUI frame (own `ui_page`), so
-- this talks to it with the raw natives directly -- Kora.nui.* would dispatch
-- into kora_lib's own resource VM/frame instead of this one.

local activeSession -- { mode, service, mandatory, shopLabel, tattoos } while the NUI is open, else nil
local disableControlsThread = false
local refreshShopPrompt -- set when Config.interactionMode == 'textui'; see shop targets below
local previewTattoos = {}
local startUndressDeathWatch -- assigned below triggerOrError; cancels a tattoo session if the player dies in it
local setTattooPedsFaded -- assigned in the tattoo artist section at the end of the file

-- Component 0 is the freemode head drawable. On its own it does nothing
-- visible, because the face is drawn from head blend data. So the "Head"
-- category in the menu drives the face shape: the chosen drawable index is used
-- as the head-blend shape id (see faceShapeFromDrawable / applyHead). The
-- drawable is already saved with the outfit as component "0", so the face
-- persists with no extra schema.
local HEAD_COMPONENT = 0
local MAX_FACE_SHAPE = 45 -- freemode head blend shape ids are 0..45

-- kora_hud is optional: kora_clothing can still run on servers with a different HUD.
-- Remember whether this session actually hid a visible kora_hud instance so its
-- close path never reveals a HUD another resource (or the player) had hidden.
local function hideHudForSession()
    if type(GetResourceState) ~= 'function' or GetResourceState('kora_hud') ~= 'started' then return false end

    local ok, visible = pcall(function() return exports['kora_hud']:isVisible() end)
    if not ok or visible ~= true then return false end

    return pcall(function() exports['kora_hud']:hide() end)
end

local function restoreHudForSession(session)
    if not session or session.hudHidden ~= true then return end
    if type(GetResourceState) ~= 'function' or GetResourceState('kora_hud') ~= 'started' then return end
    pcall(function() exports['kora_hud']:show() end)
end

-- Fallback for servers without kora_hud, which hides the radar with the rest of
-- the HUD. Only a radar this session hid is brought back, so a radar the player
-- or another resource had already hidden stays hidden.
local function hideRadarForSession()
    if not Config.hideRadarInMenu then return false end
    if type(GetResourceState) == 'function' and GetResourceState('kora_hud') == 'started' then return false end
    if type(IsRadarHidden) == 'function' and IsRadarHidden() then return false end

    DisplayRadar(false)
    return true
end

local function restoreRadarForSession(session)
    if session and session.radarHidden == true then DisplayRadar(true) end
end

-- Session-local mirror of the two hair-palette indices currently on the ped.
-- Held here rather than read back with GetPedHairColor/GetPedHairHighlightColor
-- for the same reason previewTattoos is: there is no reliable getter for what
-- was applied (the highlight getter is missing on some builds), and the NUI is
-- the only thing that ever changes these, so this IS the authority.
local previewHair = { color = 0, highlight = 0 }

-- GTA facial features are head data, not drawable components.  Keep them in
-- the same session-local form as hair so creation previews are persisted with
-- the rest of the appearance instead of being lost after the menu closes.
local previewHead = Shared.sanitiseHead()

-- Style, opacity and colour for each Shared.headOverlays entry (facial hair,
-- eyebrows). Colour -1 follows the hair colour, as facial hair always has, so
-- this also runs after a hair recolour. A picked colour is its own palette index
-- (SetPedHeadOverlayColor colorType 1), independent of SetPedHairColor, except
-- eyebrows under Config.headOverlays.eyebrows.followHairColor.
local function applyHeadOverlays(ped)
    for _, overlay in ipairs(Shared.headOverlays) do
        local style = previewHead[overlay.style]
        SetPedHeadOverlay(ped, overlay.overlay, style, previewHead[overlay.opacity])
        if style >= 0 and type(SetPedHeadOverlayColor) == 'function' then
            local color = previewHead[overlay.color]
            color = (color >= 0 and not Shared.overlayFollowsHair(overlay.key)) and color or previewHair.color
            SetPedHeadOverlayColor(ped, overlay.overlay, 1, color, color)
        end
    end
end

-- The face shape is whatever head drawable (component 0) is currently on the
-- ped, clamped to the valid head-blend shape range.
local function faceShapeFromDrawable(ped)
    local drawable = GetPedDrawableVariation(ped, HEAD_COMPONENT)
    if type(drawable) ~= 'number' or drawable < 0 then return 0 end
    return math.min(drawable, MAX_FACE_SHAPE)
end

local function applyHead(ped, head)
    -- Test harnesses and old FiveM artifacts may not expose the head natives;
    -- the rest of an appearance must still be applicable in that environment.
    if type(SetPedHeadBlendData) ~= 'function' or type(SetPedHeadOverlay) ~= 'function' then return end
    previewHead = Shared.sanitiseHead(head)
    local shape = faceShapeFromDrawable(ped)
    -- Both shape parents use the selected face, and both skin parents use the
    -- selected skin-palette entry, so each control gives a predictable,
    -- full-strength result.
    SetPedHeadBlendData(ped, shape, shape, 0, previewHead.skinTone, previewHead.skinTone, 0, 0.0, 0.0, 0.0, false)
    applyHeadOverlays(ped)
end

-- Session-local, never sent to the server or persisted: what a tattoo/barber/
-- hairdresser session temporarily overrode (bare skin for tattoos, hat/mask
-- removed for hair work) so it can be put back exactly as found on close.
-- { components = { [id] = { d, t } }, props = { [id] = { d, t } | false } }
local temporaryOverride = nil

local function notify(message, kind)
    Kora.notify.send({ title = 'Clothing', message = message, type = kind or 'info' })
end

local function sanitiseTattoos(model, tattoos)
    return Shared.sanitiseTattoos(model, tattoos)
end

local function applyTattoos(ped, model, tattoos)
    previewTattoos = sanitiseTattoos(model, tattoos)
    ClearPedDecorations(ped)
    for _, id in ipairs(previewTattoos) do
        local tattoo = Shared.tattooById(model, id)
        if tattoo then AddPedDecorationFromHashes(ped, joaat(tattoo.collection), joaat(tattoo.overlay)) end
    end
end

-- The hair palette's real length is a live query, exactly like the drawable
-- counts below. GetNumHairColors is absent on some older client builds, in
-- which case this degrades to the coarse shared bound the server already
-- clamps to rather than dropping the clamp altogether.
local function hairColorCount()
    if type(GetNumHairColors) ~= 'function' then return Shared.maxHairColorIndex + 1 end
    local count = GetNumHairColors()
    if type(count) ~= 'number' or count <= 0 then return Shared.maxHairColorIndex + 1 end
    return count
end

local function clampHairColor(value)
    local index = Shared.clampHairColor(value)
    if index >= hairColorCount() then return 0 end
    return index
end

local function applyHairColor(ped, color, highlight)
    previewHair.color, previewHair.highlight = clampHairColor(color), clampHairColor(highlight)
    SetPedHairColor(ped, previewHair.color, previewHair.highlight)
end

-- GTA applies a hair tint to the *currently loaded* hair drawable.  A normal
-- skin application already sets component 2 before applyHairColor, but a
-- palette click does not change the drawable at all.  Re-applying the current
-- valid variation first gives the renderer the same component-then-tint order
-- on a live preview, rather than merely moving the selected ring in the NUI.
-- Keep the live bounds checks here too: applying an invalid component index
-- can fault inside the game engine rather than returning a Lua error.
local function refreshHairVariation(ped)
    local drawable = GetPedDrawableVariation(ped, 2)
    local drawableCount = GetNumberOfPedDrawableVariations(ped, 2)
    if type(drawable) ~= 'number' or drawable < 0 or drawable >= drawableCount then return end

    local texture = GetPedTextureVariation(ped, 2)
    local textureCount = GetNumberOfPedTextureVariations(ped, 2, drawable)
    if type(texture) ~= 'number' or texture < 0 or texture >= textureCount then texture = 0 end

    SetPedComponentVariation(ped, 2, drawable, texture, 0)
end

-- The palette the NUI renders as swatch grids. GTA's hair colouring is
-- INDEXED: SetPedHairColor(ped, colorId, highlightColorId) takes two entries
-- from this fixed palette and there is no native that accepts an RGB triple --
-- so do NOT "fix" the swatch grids into a free colour picker, because there is
-- nothing to send an arbitrary colour to. What CAN be done is show the player
-- the real colour sitting behind each index, which is exactly what
-- GetPedHairRgbColor returns: the grid then looks like a colour picker while
-- every value crossing the wire stays a legal palette index. Built once per
-- session -- the palette does not change while a ped is alive.
local function buildHairPalette()
    local palette = {}
    for index = 0, hairColorCount() - 1 do
        local r, g, b = GetPedHairRgbColor(index)
        palette[#palette + 1] = {
            index = index,
            r = math.floor(tonumber(r) or 0),
            g = math.floor(tonumber(g) or 0),
            b = math.floor(tonumber(b) or 0),
        }
    end
    return palette
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
    applyHairColor(ped, skin.hairColor, skin.hairHighlight)
    applyHead(ped, skin.head)
    -- SetPedHeadBlendData (inside applyHead) re-initialises the freemode head
    -- and drops a tint set before it, so the hair tint is asserted again once
    -- the blend data is in place, then the overlays that follow it are
    -- recoloured. The menu path gets this order for free: its colour is set on
    -- an already-blended ped.
    applyHairColor(ped, skin.hairColor, skin.hairHighlight)
    if type(SetPedHeadOverlay) == 'function' then applyHeadOverlays(ped) end
    applyTattoos(ped, model, skin.tattoos)
end

-- Re-asserts only the colour fields (hair tint, overlay colours) of an already
-- applied skin. Used after login, when the spawn flow (resurrect/teleport/fade)
-- can still reset the ped's tints after the skin has been applied.
local function reapplyColours(ped, skin)
    refreshHairVariation(ped)
    applyHairColor(ped, skin.hairColor, skin.hairHighlight)
    if type(SetPedHeadOverlay) == 'function' then applyHeadOverlays(ped) end
end

local function currentSkinSnapshot(ped)
    local skin = {
        components = {}, props = {}, tattoos = previewTattoos,
        hairColor = previewHair.color, hairHighlight = previewHair.highlight,
        head = previewHead,
    }
    for id in pairs(Shared.components) do
        skin.components[tostring(id)] = { d = GetPedDrawableVariation(ped, id), t = GetPedTextureVariation(ped, id) }
    end
    for id in pairs(Shared.props) do
        local drawable = GetPedPropIndex(ped, id)
        if drawable >= 0 then
            skin.props[tostring(id)] = { d = drawable, t = GetPedPropTextureIndex(ped, id) }
        end
    end
    -- Whatever a session bared for preview (tattoo undress buttons, barber
    -- hat/mask) is reported as what the player was wearing, so a confirm can
    -- never save the bare look.
    if temporaryOverride then
        for id, variation in pairs(temporaryOverride.components) do
            skin.components[tostring(id)] = { d = variation.d, t = variation.t }
        end
        for id, variation in pairs(temporaryOverride.props) do
            skin.props[tostring(id)] = variation and { d = variation.d, t = variation.t } or nil
        end
    end
    return skin
end

local function servicePolicy(service)
    return Config.services[service] or Config.services.clothing
end

local function policyAllows(policy, ids, id)
    if policy.all then return true end
    for _, candidate in ipairs(ids or {}) do if candidate == id then return true end end
    return false
end

-- Hair colour is only offered where the hair component itself is editable --
-- barber, hairdresser, character creation and the admin session. An ordinary
-- clothing shop gets no palette at all, so the NUI has nothing to render there
-- and cannot show a control the server would refuse anyway (mergeServiceSkin
-- keeps hair colour on the same whitelist as component 2).
local function hairPayload(service)
    local policy = servicePolicy(service)
    if not policyAllows(policy, policy.components, 2) then return nil end
    return { palette = buildHairPalette(), color = previewHair.color, highlight = previewHair.highlight }
end

-- Menu text. locales/en.json holds the English defaults; kora_lib (Kora.lang,
-- language from the qb_locale convar) swaps in a translation when the server
-- has locales/<language>.json for a key. The NUI shows whatever it is sent, so
-- wording lives in the locale files rather than in the UI bundle.
local defaultStrings
local function uiStrings()
    if not defaultStrings then
        defaultStrings = {}
        local raw = type(LoadResourceFile) == 'function' and LoadResourceFile(GetCurrentResourceName(), 'locales/en.json')
        local ok, decoded = pcall(function() return json.decode(raw) end)
        if ok and type(decoded) == 'table' and type(decoded.ui) == 'table' then defaultStrings = decoded.ui end
    end
    local strings = {}
    for key, fallback in pairs(defaultStrings) do
        local path = 'ui.' .. key
        local ok, text = pcall(function() return Kora.lang(path) end)
        strings[key] = (ok and type(text) == 'string' and text ~= path) and text or fallback
    end
    return strings
end

-- The current head plus what this service may edit, so the NUI shows only
-- those controls. Nil when the service can edit nothing about the head.
local function headPayload(service)
    local policy = servicePolicy(service)
    if not Shared.headEditable(policy) then return nil end
    local payload = Shared.sanitiseHead(previewHead)
    payload.skinToneEditable = policy.all == true
    payload.overlays = {}
    payload.overlayColors = {}
    for _, overlay in ipairs(Shared.headOverlays) do
        payload.overlays[overlay.key] = Shared.headOverlayEnabled(policy, overlay.key)
        payload.overlayColors[overlay.key] = not Shared.overlayFollowsHair(overlay.key)
    end
    return payload
end

local function buildCategoryPayload(ped, service)
    local categories = {}
    local policy = servicePolicy(service)
    for id, meta in pairs(Shared.components) do
        if policyAllows(policy, policy.components, id) then
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
        if policyAllows(policy, policy.props, id) then
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

local function currentModelName(ped)
    return GetEntityModel(ped) == joaat(Shared.models.female) and Shared.models.female or Shared.models.male
end

local function switchModel(model)
    local ped = PlayerPedId()
    local hash = joaat(model)
    if GetEntityModel(ped) ~= hash then
        local loaded = Kora.stream.loadModel(hash, nil, { timeout = 5000 })
        if not loaded then return nil end
        SetPlayerModel(PlayerId(), hash)
        SetModelAsNoLongerNeeded(hash)
        ped = PlayerPedId()
        SetPedDefaultComponentVariation(ped)
    end
    return ped
end

local function applyModel(model, skin)
    local ped = switchModel(model)
    if not ped then return false end
    applySkin(ped, skin, model)
    return true
end

-- Built on `temporaryOverride`: that table already records the original
-- component/prop of everything a session bared, and every close path already
-- puts it back (confirm -> restoreTemporaryOverride, cancel/ESC/death ->
-- applyModel of the pre-session appearance). Nothing here is sent to the
-- server, and the confirm snapshot is patched back to the originals (see
-- currentSkinSnapshot), so a bared part can never be saved or charged.
local undressActive = {} -- part id -> true while that part is bared

local function undressConfig()
    local cfg = Config.tattoo and Config.tattoo.undress
    if type(cfg) ~= 'table' or cfg.enabled ~= true then return nil end
    return cfg
end

local function undressPartById(cfg, id)
    for _, part in ipairs(cfg.parts or {}) do
        if part.id == id then return part end
    end
end

-- Bounds-checked like applySkin: an out-of-range drawable faults the game.
local function setBareComponent(ped, entry, override)
    local id, drawable, texture = tonumber(entry.id), tonumber(entry.d), tonumber(entry.t) or 0
    if not id or not drawable or drawable < 0 then return end
    if drawable >= GetNumberOfPedDrawableVariations(ped, id) then return end
    if texture < 0 or texture >= GetNumberOfPedTextureVariations(ped, id, drawable) then texture = 0 end
    if not override.components[id] then
        override.components[id] = { d = GetPedDrawableVariation(ped, id), t = GetPedTextureVariation(ped, id) }
    end
    SetPedComponentVariation(ped, id, drawable, texture, 0)
end

local function setPartUndressed(ped, model, part, undressed)
    temporaryOverride = temporaryOverride or { components = {}, props = {} }
    local override = temporaryOverride

    for _, entry in ipairs(part[Shared.modelGender(model)] or {}) do
        if undressed then
            setBareComponent(ped, entry, override)
        else
            local saved = override.components[entry.id]
            if saved then
                SetPedComponentVariation(ped, entry.id, saved.d, saved.t, 0)
                override.components[entry.id] = nil
            end
        end
    end

    for _, id in ipairs(part.props or {}) do
        if undressed then
            if override.props[id] == nil then
                local drawable = GetPedPropIndex(ped, id)
                override.props[id] = drawable >= 0 and { d = drawable, t = GetPedPropTextureIndex(ped, id) } or false
            end
            ClearPedProp(ped, id)
        else
            local saved = override.props[id]
            if saved ~= nil then
                if saved then SetPedPropIndex(ped, id, saved.d, saved.t, true) else ClearPedProp(ped, id) end
                override.props[id] = nil
            end
        end
    end

    undressActive[part.id] = undressed or nil
end

local function activeUndressParts(cfg)
    local active = {}
    for _, part in ipairs(cfg.parts or {}) do
        if undressActive[part.id] then active[#active + 1] = part.id end
    end
    return active
end

---What the NUI needs to draw the buttons; nil when this session has none.
local function undressPayload(service)
    local cfg = undressConfig()
    if not cfg or service ~= 'tattoo' then return nil end
    local parts = {}
    for _, part in ipairs(cfg.parts or {}) do
        parts[#parts + 1] = { id = part.id, label = part.label or part.id }
    end
    return { parts = parts, active = activeUndressParts(cfg) }
end

local function applyAutoUndress(ped, model)
    local cfg = undressConfig()
    if not cfg then return false end
    for _, id in ipairs(cfg.autoUndressOnOpen or {}) do
        local part = undressPartById(cfg, id)
        if part then setPartUndressed(ped, model, part, true) end
    end
    return true
end

---Puts the parts that were bared before a full appearance swap (loading an
---outfit) back to bare, capturing the new look as the originals.
local function reapplyUndress(ped, model, active)
    local cfg = undressConfig()
    temporaryOverride, undressActive = nil, {}
    if not cfg then return end
    for _, id in ipairs(active) do
        local part = undressPartById(cfg, id)
        if part then setPartUndressed(ped, model, part, true) end
    end
end

-- Barber / hairdresser "shirt off" preview, so chest hair can be seen. It rides
-- on the same temporaryOverride as the tattoo undress buttons, so confirm,
-- cancel, Esc, death and resource stop all put the original top back and the
-- confirm snapshot never carries the bare one. The bare drawables are the `top`
-- part of Config.tattoo.undress.parts (read whether or not the tattoo buttons
-- are enabled), with the stock freemode values as a fallback.
local BARE_TOP = {
    id = 'top',
    male = { { id = 3, d = 15, t = 0 }, { id = 8, d = 15, t = 0 }, { id = 11, d = 15, t = 0 } },
    female = { { id = 3, d = 15, t = 0 }, { id = 8, d = 15, t = 0 }, { id = 11, d = 15, t = 0 } },
    props = {},
}

local function barberTopPart()
    local cfg = Config.tattoo and Config.tattoo.undress
    for _, part in ipairs(type(cfg) == 'table' and cfg.parts or {}) do
        if part.id == 'top' then return part end
    end
    return BARE_TOP
end

local function topToggleAvailable(service)
    return (service == 'barber' or service == 'hairdresser') and (Config.ui or {}).barberTopToggle ~= false
end

---What the NUI needs for the shirt button; nil when this session has none.
local function topTogglePayload(service)
    if not topToggleAvailable(service) then return nil end
    return { active = undressActive.top == true }
end

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
        -- The undress buttons replace the fixed strip below: they bare the
        -- Config.tattoo.undress.autoUndressOnOpen parts instead.
        if applyAutoUndress(ped, model) then return end

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

-- Ends a controls-mode rotate drag (client/rotate.lua) so NUI focus is never left
-- on the cursorless setting. 'close' leaves focus to the caller.
local function stopRotate(reason)
    if RotateControl then return RotateControl.stop(reason) end
    return false
end

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
        -- Every menu edit is a live preview. Keep the exact server-sanitised
        -- look that was applied when the session started so Cancel can undo
        -- those previews immediately, rather than waiting for the next menu
        -- open to re-apply the saved skin.
        previousAppearance = { model = payload.model, skin = payload.skin },
    }
    undressActive = {}
    -- The ped was just dressed from the saved skin, so any /c toggle memory is moot.
    if QuickToggle then QuickToggle.forget() end
    activeSession.hudHidden = hideHudForSession()
    activeSession.radarHidden = hideRadarForSession()

    -- After the real skin is applied, not before -- this has to override
    -- what the player actually walked in wearing, not whatever the ped's
    -- default/previous state happened to be.
    applyTemporaryStrip(ped, activeSession.service, currentModelName(ped))

    startControlLock()
    Camera.start(ped)
    if activeSession.service == 'tattoo' then
        setTattooPedsFaded(true)
    end
    -- A bared tattoo studio or barber preview must never outlive a death.
    if activeSession.service == 'tattoo' or topToggleAvailable(activeSession.service) then
        startUndressDeathWatch(activeSession)
    end

    local head = headPayload(activeSession.service)

    QBTheme.refresh()
    SendNUIMessage({
        action = 'qbclothing:nui:open',
        data = {
            mode = payload.mode,
            service = activeSession.service,
            free = payload.free == true,
            mandatory = activeSession.mandatory,
            rotatePointerLock = Config.rotatePointerLock ~= false,
            rotateDragGuard = Config.rotateDragGuard ~= false,
            rotateMode = RotateControl and RotateControl.mode() or 'pointer',
            rotateRightButton = Config.rotateRightButton ~= false,
            rotateInvert = Config.rotateInvert == true,
            rotateSensitivity = tonumber(Config.rotateSensitivity),
            rotateRecenterEdge = tonumber(Config.rotateRecenterEdge),
            showControlsHint = (Config.ui or {}).showControlsHint ~= false,
            creatorOpensOnHair = (Config.ui or {}).creatorOpensOnHair ~= false,
            shopLabel = payload.shopLabel,
            -- Read back off the live ped, not echoed from the request --
            -- if the requested model failed to stream in time, this must
            -- reflect what the player is actually wearing, not what was asked for.
            model = currentModelName(ped),
            categories = buildCategoryPayload(ped, activeSession.service),
            hair = hairPayload(activeSession.service),
            head = head,
            undress = undressPayload(activeSession.service),
            topToggle = topTogglePayload(activeSession.service),
            strings = uiStrings(),
            tattoos = payload.tattoos or {},
            selectedTattoos = previewTattoos,
            tattooStacking = Shared.tattooStacking(),
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
    stopRotate('close')
    Camera.stop()
    stopControlLock()
    setTattooPedsFaded(false)
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
        -- Cancelled (or otherwise interrupted): discard the live preview and
        -- restore the full appearance from when the session opened. A full
        -- restore already includes every component/prop a specialist session
        -- temporarily stripped, so do not layer that override on top of it.
        local previousAppearance = activeSession.previousAppearance
        if previousAppearance then
            temporaryOverride = nil
            applyModel(previousAppearance.model, previousAppearance.skin)
        else
            restoreTemporaryOverride(PlayerPedId())
        end
    end
    local session = activeSession
    activeSession = nil
    undressActive = {}
    restoreHudForSession(session)
    restoreRadarForSession(session)
    if refreshShopPrompt then refreshShopPrompt() end
    TriggerEvent('qb-clothing:client:onMenuClose')
end)

RegisterNUICallback('qbclothing:nui:setVariation', function(data, cb)
    if not activeSession or type(data) ~= 'table' then cb({ ok = false }); return end
    local ped = PlayerPedId()
    local id = tonumber(data.id)

    if data.kind == 'component' and id == HEAD_COMPONENT and Shared.components[id] then
        -- Face change: keep the drawable in range (an out-of-range index faults
        -- the game), store it on the ped so it saves with the outfit, then
        -- rebuild the head blend so the face actually changes on screen.
        local drawableCount = GetNumberOfPedDrawableVariations(ped, id)
        local drawable = math.max(0, tonumber(data.drawable) or 0)
        if drawable >= drawableCount then drawable = 0 end
        local textureCount = GetNumberOfPedTextureVariations(ped, id, drawable)
        local texture = math.max(0, tonumber(data.texture) or 0)
        if texture >= textureCount then texture = 0 end

        SetPedComponentVariation(ped, id, drawable, texture, 0)
        applyHead(ped, previewHead)
        cb({
            ok = true,
            drawable = drawable,
            texture = GetPedTextureVariation(ped, id),
            drawableCount = drawableCount,
            textureCount = textureCount,
        })
    elseif data.kind == 'component' and id and Shared.components[id] then
        local drawable = math.max(0, tonumber(data.drawable) or 0)
        SetPedComponentVariation(ped, id, drawable, math.max(0, tonumber(data.texture) or 0), 0)
        -- The player chose this slot while a tattoo preview had it bared: their
        -- choice is the outfit to keep, not the one remembered from before.
        if temporaryOverride and activeSession.service ~= 'tattoo' and temporaryOverride.components[id] then
            temporaryOverride.components[id] = { d = GetPedDrawableVariation(ped, id), t = GetPedTextureVariation(ped, id) }
        end
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
        if temporaryOverride and activeSession.service ~= 'tattoo' and temporaryOverride.props[id] ~= nil then
            temporaryOverride.props[id] = GetPedPropIndex(ped, id) >= 0
                and { d = GetPedPropIndex(ped, id), t = GetPedPropTextureIndex(ped, id) } or false
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

-- Tattoo group -> Config.tattoo.undress.parts id that covers it.
local TATTOO_GROUP_PARTS = { Head = 'headwear', Torso = 'top', Arms = 'top', Back = 'top', Legs = 'legs' }

---Character creation (any non-tattoo session that offers tattoos): the studio
---strips on open, but here the outfit stays on and hides the tattoo being
---previewed. Bares the covering part (Config.tattoo.undress.previewInCreator).
---The change goes through temporaryOverride, so it is never saved.
local function previewTattooArea(ped, model, before, after)
    if activeSession.service == 'tattoo' then return end
    local cfg = Config.tattoo and Config.tattoo.undress
    if type(cfg) ~= 'table' or cfg.previewInCreator == false then return end

    local counts = Shared.tattooCounts(before)
    for _, id in ipairs(after) do
        if (counts[id] or 0) > 0 then
            counts[id] = counts[id] - 1
        else
            local tattoo = Shared.tattooById(model, id)
            local part = tattoo and undressPartById(cfg, TATTOO_GROUP_PARTS[tattoo.group])
            if part then setPartUndressed(ped, model, part, true) end
        end
    end
end

RegisterNUICallback('qbclothing:nui:setTattoos', function(data, cb)
    if not activeSession or type(data) ~= 'table' then cb({ ok = false }); return end
    local policy = Config.services[activeSession.service] or {}
    if not policy.tattoos then cb({ ok = false }); return end
    local ped = PlayerPedId()
    local model = currentModelName(ped)
    local before = previewTattoos
    applyTattoos(ped, model, data.tattoos)
    previewTattooArea(ped, model, before, previewTattoos)
    cb({ ok = true, tattoos = previewTattoos })
end)

-- Preview-only clothing buttons in the tattoo studio. `part` is a part id from
-- Config.tattoo.undress.parts, or 'all'; `undressed` says which way. The reply
-- carries the parts now bared so the buttons always show the real state.
RegisterNUICallback('qbclothing:nui:setUndress', function(data, cb)
    local cfg = undressConfig()
    if not activeSession or activeSession.service ~= 'tattoo' or not cfg or type(data) ~= 'table' then
        cb({ ok = false }); return
    end
    local ped = PlayerPedId()
    local model = currentModelName(ped)
    local undressed = data.undressed == true
    if data.part == 'all' then
        for _, part in ipairs(cfg.parts or {}) do setPartUndressed(ped, model, part, undressed) end
    else
        local part = undressPartById(cfg, data.part)
        if not part then cb({ ok = false }); return end
        setPartUndressed(ped, model, part, undressed)
    end
    cb({ ok = true, active = activeUndressParts(cfg) })
end)

-- Preview-only shirt button in the barber and hairdresser menu (see barberTopPart).
RegisterNUICallback('qbclothing:nui:setTop', function(data, cb)
    if not activeSession or type(data) ~= 'table' or not topToggleAvailable(activeSession.service) then
        cb({ ok = false }); return
    end
    local ped = PlayerPedId()
    setPartUndressed(ped, currentModelName(ped), barberTopPart(), data.undressed == true)
    cb({ ok = true, active = undressActive.top == true })
end)

RegisterNUICallback('qbclothing:nui:setHairColor', function(data, cb)
    if not activeSession or type(data) ~= 'table' then cb({ ok = false }); return end
    -- Same gate the server applies at confirm time, so the preview can never
    -- show a recolour a clothing shop's merge would silently throw away.
    local policy = servicePolicy(activeSession.service)
    if not policyAllows(policy, policy.components, 2) then cb({ ok = false }); return end
    local ped = PlayerPedId()
    refreshHairVariation(ped)
    applyHairColor(ped, data.color, data.highlight)
    if type(SetPedHeadOverlay) == 'function' then applyHeadOverlays(ped) end
    cb({ ok = true, color = previewHair.color, highlight = previewHair.highlight })
end)

RegisterNUICallback('qbclothing:nui:setHead', function(data, cb)
    if not activeSession or type(data) ~= 'table' then cb({ ok = false }); return end
    local policy = servicePolicy(activeSession.service)
    if not Shared.headEditable(policy) then
        cb({ ok = false })
        return
    end
    local ped = PlayerPedId()
    -- Same merge the server applies at confirm time, so the preview never
    -- shows skin tone or an overlay this service would discard.
    applyHead(ped, Shared.mergeHead(policy, previewHead, data))
    -- skinTone/beard stay top-level for the original response shape.
    cb({ ok = true, head = previewHead, skinTone = previewHead.skinTone, beard = previewHead.beard })
end)

RegisterNUICallback('qbclothing:nui:camera', function(data, cb)
    if type(data) ~= 'table' then cb({}); return end
    -- `category` is a clothing or tattoo group picked in the menu; `zone` is
    -- the toolbar's explicit choice and always applies.
    if data.zone then
        Camera.setZone(data.zone)
    elseif data.category then
        Camera.setCategory(data.category)
    end
    cb({ zone = Camera.currentZone() })
end)

RegisterNUICallback('qbclothing:nui:rotate', function(data, cb)
    if type(data) == 'table' then Camera.rotate(data.deltaDeg) end
    cb({})
end)

-- The NUI says the drag is over (button up, cursor left the window, focus
-- lost): settle the orbit where it is so nothing keeps rotating.
RegisterNUICallback('qbclothing:nui:rotateEnd', function(_, cb)
    Camera.rotateEnd()
    stopRotate('nui')
    cb({})
end)

-- Config.rotateMode = 'controls': the NUI hands the drag to Lua, which reads the
-- mouse as a game control until the button is released (client/rotate.lua).
-- `active = false` means the NUI keeps its own cursor drag.
RegisterNUICallback('qbclothing:nui:rotateStart', function(data, cb)
    local started = false
    if activeSession and type(data) == 'table' and RotateControl then
        started = RotateControl.start(data.button, data.x, data.y)
    end
    cb({ active = started })
end)

-- Config.rotateMode = 'recenter': the cursor got close to a screen edge mid-drag.
RegisterNUICallback('qbclothing:nui:recenter', function(_, cb)
    local moved = false
    if activeSession and RotateControl then moved = RotateControl.recenter() end
    cb({ moved = moved })
end)

RegisterNUICallback('qbclothing:nui:zoom', function(data, cb)
    if type(data) == 'table' then Camera.zoom(data.delta) end
    cb({})
end)

RegisterNUICallback('qbclothing:nui:loadOutfit', function(data, cb)
    if not activeSession or type(data) ~= 'table' then cb({ ok = false }); return end
    local model, skin = Kora.callback.trigger('qbclothing:server:getOutfitSkin', tonumber(data.id))
    if not model then cb({ ok = false }); return end
    local wasUndressed = {}
    for id in pairs(undressActive) do wasUndressed[#wasUndressed + 1] = id end
    applyModel(model, skin)
    local ped = PlayerPedId()
    -- The outfit replaced every component, so the recorded originals are stale:
    -- re-bare whatever was bared against the newly loaded look.
    if activeSession.service == 'tattoo' then
        reapplyUndress(ped, currentModelName(ped), wasUndressed)
    elseif undressActive.top and topToggleAvailable(activeSession.service) then
        local part, model = barberTopPart(), currentModelName(ped)
        for _, entry in ipairs(part[Shared.modelGender(model)] or {}) do
            if temporaryOverride then temporaryOverride.components[entry.id] = nil end
        end
        setPartUndressed(ped, model, part, true)
    end
    cb({
        ok = true,
        undress = undressPayload(activeSession.service),
        topToggle = topTogglePayload(activeSession.service),
        model = currentModelName(ped),
        categories = buildCategoryPayload(ped, activeSession.service),
        hair = hairPayload(activeSession.service),
        head = headPayload(activeSession.service),
        selectedTattoos = previewTattoos,
    })
end)

-- These four fire the tokenised Kora.events gateway (server/server.lua) rather
-- than a raw TriggerServerEvent -- trigger() can fail if the connect-time
-- handshake hasn't landed yet (10s timeout), which the existing sessionError
-- display already handles, so a failure here is surfaced the same way any
-- other server-side rejection of these actions already is.
local function triggerOrError(name, ...)
    local ok, err = Kora.events.trigger(name, ...)
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

-- A player who dies in the studio would otherwise be stuck on a menu with a
-- half-undressed corpse: put the preview clothing back and end the session.
-- A mandatory session cannot be cancelled, so it only restores the clothing.
startUndressDeathWatch = function(session)
    CreateThread(function()
        while activeSession == session do
            if IsEntityDead(PlayerPedId()) then
                restoreTemporaryOverride(PlayerPedId())
                undressActive = {}
                if not session.mandatory then triggerOrError('qbclothing:server:cancelSession') end
                return
            end
            Wait(500)
        end
    end)
end

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
-- kora_hud's client/bridge/qbcore.lua loginGeneration pattern.
local skinApplyGeneration = 0

local function applySavedSkin()
    skinApplyGeneration = skinApplyGeneration + 1
    local generation = skinApplyGeneration

    CreateThread(function()
        local model, skin = Kora.callback.trigger('qb-clothing:server:getSkin')
        if generation ~= skinApplyGeneration then return end

        -- The callback trigger is a network round trip -- a fitting-room
        -- session can legitimately open while it's in flight (e.g. another
        -- resource calls exports.kora_clothing:OpenWardrobe() right after
        -- login). Applying a late-arriving saved skin at that point would
        -- silently clobber whatever the player is currently trying on.
        if not model or activeSession then return end
        if not applyModel(model, skin) then return end

        local retry = Config.loginColourReapply
        if type(retry) ~= 'table' or retry.enabled ~= true then return end
        local previous = 0
        for _, delay in ipairs(retry.delays or {}) do
            Wait(math.max(0, delay - previous))
            previous = delay
            -- A newer login apply, or a fitting-room session, owns the ped now.
            if generation ~= skinApplyGeneration or activeSession then return end
            local ped = PlayerPedId()
            if currentModelName(ped) ~= model then return end
            reapplyColours(ped, skin or {})
        end
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', applySavedSkin)

-- Additional path for "this resource just restarted while a player was
-- already logged in" (e.g. `ensure kora_clothing` mid-session): the legacy
-- OnPlayerLoaded event above does NOT re-fire on a resource restart, so
-- without this a restarted kora_clothing leaves the player's saved skin
-- un-applied until they relog. Mirrors kora_hud's client/bridge/qbcore.lua --
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
-- kora_core's compat (qb-multicharacter:server:createCharacter handler) fires
-- this client event ONLY on successful character creation, never on an
-- existing-character login (that path goes through qb-spawn instead).
--
-- It is NOT, however, a "you are in the world" signal. kora_multichar answers it
-- by opening the mandatory cinematic spawn carousel, and the fitting room must
-- not land on top of that -- nor on the teleport/resurrect/fade-in that
-- follows the player's choice. So this handler only arms the flow; the actual
-- open waits for kora_multichar to say the spawn finished.
local firstCharacterArmed = false

-- Whether the multichar handling this login is our own, and so whether a
-- completion event is coming at all. Asked at arm time, not at chunk load:
-- kora_clothing and kora_multichar start in the same batch, so a chunk-load read can
-- catch kora_multichar as 'starting' and silently strand the session on the
-- fallback path. By the time a character has been created both are running.
-- Preferred over sniffing the `qbmultichar:mode` state bag, which answers a
-- timing question ("has the mode replicated yet") rather than the capability
-- question actually being asked here.
local function hasSpawnCompleteSignal()
    return GetResourceState('kora_multichar') == 'started'
end

RegisterNetEvent('qb-multicharacter:client:closeNUIdefault', function()
    if hasSpawnCompleteSignal() then
        firstCharacterArmed = true
        return
    end

    -- Third-party qb-multicharacter: no completion event exists to wait for,
    -- so fall back to observing the ped directly. Unchanged legacy behaviour.
    CreateThread(function()
        local timeout = GetGameTimer() + 15000
        while (not NetworkIsPlayerActive(PlayerId()) or IsEntityDead(PlayerPedId())) and GetGameTimer() < timeout do
            Wait(50)
        end
        Wait(250)
        TriggerEvent('qb-clothing:client:CreateFirstCharacter')
    end)
end)

-- kora_multichar fires this once the ped has been placed, resurrected, revealed
-- and unfrozen and the fade-in has completed -- i.e. the player can genuinely
-- see themselves. `isNew` is its own record of which path the spawn came from;
-- the armed flag is checked as well so that an ordinary login can never open
-- the creation fitting room even if the two ever disagree.
AddEventHandler('qbmultichar:client:spawnComplete', function(isNew)
    if not firstCharacterArmed then return end
    firstCharacterArmed = false
    if isNew ~= true then return end
    TriggerEvent('qb-clothing:client:CreateFirstCharacter')
end)

RegisterNetEvent('qb-clothing:client:CreateFirstCharacter', function()
    openSession('firstCharacter')
end)

-- Used by kora_admin's self-service clothing entry.  Keeping the nearest-shop
-- selection inside kora_clothing means external callers never have to duplicate
-- this resource's shop ordering; the server still performs the authoritative
-- distance check when it receives requestSession('shop', index).
local function openNearestShop(service)
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
        Kora.notify.send({ type = 'error', message = ('You are not near a %s shop'):format(service) })
        return
    end
    openSession('shop', { shopId = nearestIndex })
end

RegisterNetEvent('qbclothing:client:openNearestShop', openNearestShop)

RegisterNetEvent('qb-clothing:client:openMenu', function(shopType)
    if shopType == nil then return openNearestShop('clothing') end
    openSession('shop', type(shopType) == 'table' and shopType or { shopId = tonumber(shopType) or 1 })
end)

RegisterNetEvent('qb-clothing:client:openOutfitMenu', function()
    openSession('wardrobe')
end)

-- Admin-only combined session: clothing + hair + tattoos in one sitting, free
-- and with no shop/model restrictions (mirrors the character-creation
-- service policy). Permission is re-checked server-side in requestSession --
-- this event is just the trigger.
RegisterNetEvent('qbclothing:client:openAdminSession', function(service)
    openSession('admin', service and { service = service } or nil)
end)

local STOCK_COMPONENT_IDS = {
    face = 0, mask = 1, hair = 2, arms = 3, pants = 4, bag = 5, shoes = 6,
    accessory = 7, ['t-shirt'] = 8, vest = 9, decals = 10, torso2 = 11,
}
local STOCK_PROP_IDS = { hat = 0, glass = 1, ear = 2, watch = 6, bracelet = 7 }

local function stockEntry(entry)
    if type(entry) ~= 'table' then return nil end
    local item, texture = tonumber(entry.item), tonumber(entry.texture) or 0
    if not item or item ~= item then return nil end
    return math.floor(item), math.max(0, math.floor(texture))
end

local function setOutfitComponent(ped, id, drawable, texture)
    if drawable < 0 then drawable = 0 end
    if drawable >= GetNumberOfPedDrawableVariations(ped, id) then return end
    if texture >= GetNumberOfPedTextureVariations(ped, id, drawable) then texture = 0 end
    SetPedComponentVariation(ped, id, drawable, texture, 0)
end

local function setOutfitProp(ped, id, drawable, texture)
    if drawable <= 0 then ClearPedProp(ped, id); return end
    if drawable >= GetNumberOfPedPropDrawableVariations(ped, id) then return end
    if texture >= GetNumberOfPedPropTextureVariations(ped, id, drawable) then texture = 0 end
    SetPedPropIndex(ped, id, drawable, texture, true)
end

---Overlays stock qb-clothing outfit keys on the current ped; never changes the model.
local function overlayStockOutfit(ped, data)
    for key, id in pairs(STOCK_COMPONENT_IDS) do
        local drawable, texture = stockEntry(data[key])
        if drawable and key ~= 'face' then
            if key == 'hair' then
                setOutfitComponent(ped, id, drawable, 0)
                applyHairColor(ped, texture, texture)
            else
                setOutfitComponent(ped, id, drawable, texture)
            end
        end
    end
    for key, id in pairs(STOCK_PROP_IDS) do
        local drawable, texture = stockEntry(data[key])
        if drawable then setOutfitProp(ped, id, drawable, texture) end
    end
end

local function decodeStockTable(value)
    if type(value) == 'string' then
        local ok, decoded = pcall(json.decode, value)
        value = ok and decoded or nil
    end
    return type(value) == 'table' and value or nil
end

RegisterNetEvent('qb-clothing:client:loadOutfit', function(outfit)
    if type(outfit) ~= 'table' then return end
    local data = outfit.outfitData ~= nil and decodeStockTable(outfit.outfitData) or nil
    if data then
        overlayStockOutfit(PlayerPedId(), data)
        if type(outfit.outfitName) == 'string' and outfit.outfitName ~= '' then
            notify(('You have chosen %s! Press Confirm to confirm outfit.'):format(outfit.outfitName), 'info')
        end
        return
    end
    if outfit.outfitData ~= nil or not Shared.isFreemodeModel(outfit.model) then return end
    applyModel(outfit.model, outfit.skin)
end)

local function stockSkinToKora(data)
    local skin = { components = {}, props = {}, head = {} }
    for _, id in pairs(STOCK_COMPONENT_IDS) do skin.components[tostring(id)] = { d = 0, t = 0 } end
    for key, id in pairs(STOCK_COMPONENT_IDS) do
        local drawable, texture = stockEntry(data[key])
        if drawable and key ~= 'hair' then
            skin.components[tostring(id)] = { d = math.max(0, drawable), t = key == 'face' and 0 or texture }
        elseif drawable then
            skin.components[tostring(id)] = { d = math.max(0, drawable), t = 0 }
            skin.hairColor, skin.hairHighlight = texture, texture
        end
    end
    for key, id in pairs(STOCK_PROP_IDS) do
        local drawable, texture = stockEntry(data[key])
        if drawable and drawable > 0 then skin.props[tostring(id)] = { d = drawable, t = texture } end
    end
    local _, skinTone = stockEntry(data.face)
    skin.head.skinTone = skinTone
    local beard, beardColor = stockEntry(data.beard)
    skin.head.beard, skin.head.beardColor = beard, beardColor
    local eyebrows, eyebrowsColor = stockEntry(data.eyebrows)
    skin.head.eyebrows, skin.head.eyebrowsColor = eyebrows, eyebrowsColor
    return skin
end

local function freemodeModelName(ped)
    local hash = GetEntityModel(ped)
    for _, name in pairs(Shared.models) do
        if hash == joaat(name) then return name end
    end
    return nil
end

local function loadStockClothing(data, ped)
    data = decodeStockTable(data)
    if not data then return false end
    if type(ped) ~= 'number' or ped == 0 then ped = PlayerPedId() end
    if not DoesEntityExist(ped) then return false end
    local model = freemodeModelName(ped)
    if not model then return false end
    local skin = stockSkinToKora(data)
    if ped == PlayerPedId() then skin.tattoos = previewTattoos end
    applySkin(ped, skin, model)
    return true
end

RegisterNetEvent('qb-clothing:client:loadPlayerClothing', function(data, ped)
    loadStockClothing(data, ped)
end)

local function freemodeNameFromAny(model)
    if type(model) == 'string' and Shared.isFreemodeModel(model) then return model end
    local hash = tonumber(model)
    if not hash then return nil end
    for _, name in pairs(Shared.models) do
        if hash == joaat(name) then return name end
    end
    return nil
end

RegisterNetEvent('qb-clothes:loadSkin', function(isNew, model, data)
    if activeSession or isNew == true then return end
    local name = freemodeNameFromAny(model)
    data = decodeStockTable(data)
    if not name or not data then return end
    if type(data.components) == 'table' or type(data.props) == 'table' then
        applyModel(name, data)
        return
    end
    local ped = switchModel(name)
    if ped then loadStockClothing(data, ped) end
end)

local QUICK_PART_FOR = {
    top = 'shirt', shirt = 'shirt', pants = 'pants', shoes = 'shoes', neck = 'chain', mask = 'mask',
    vest = 'vest', bag = 'bag', bagoff = 'bag', hat = 'hat', glasses = 'glasses', visor = 'visor',
    ear = 'ears', watch = 'watch', bracelet = 'bracelet',
}

local function toggleQuickPart(which)
    if type(which) == 'table' then which = which.id end
    local part = QUICK_PART_FOR[tostring(which or ''):lower()]
    if part and QuickToggle and QuickToggle.run then QuickToggle.run(part) end
end

RegisterNetEvent('qb-radialmenu:ToggleClothing', toggleQuickPart)
RegisterNetEvent('qb-radialmenu:ToggleProps', toggleQuickPart)
RegisterNetEvent('qb-radialmenu:ResetClothing', function()
    if QuickToggle and QuickToggle.run then QuickToggle.run('reset') end
end)

local ADJUST_FACEWEAR_PART = { [1] = 'hat', [2] = 'glasses', [3] = 'ears', [4] = 'mask', [5] = 'shirt' }

RegisterNetEvent('qb-clothing:client:adjustfacewear', function(kind)
    local part = ADJUST_FACEWEAR_PART[tonumber(kind) or 0]
    if part and QuickToggle and QuickToggle.run then QuickToggle.run(part) end
end)

-- Public modern form: exports.kora_clothing:OpenClothingRoom({ shopId = 1 }).
-- The numeric form remains for existing qb-clothing consumers.
exports('OpenClothingRoom', function(options)
    openSession('shop', type(options) == 'table' and options or { shopId = tonumber(options) or 1 })
end)
exports('OpenWardrobe', function() openSession('wardrobe') end)
exports('reloadSkin', function() applySavedSkin() end)
exports('IsCreatingCharacter', function() return activeSession ~= nil and activeSession.mode == 'firstCharacter' end)
exports('getOutfits', function() openSession('wardrobe') end)
exports('IsClothingMenuOpen', function() return activeSession ~= nil end)
exports('GetPedModels', function() return Shared.models end)
-- Applies this resource's canonical component/prop/tattoo schema to an
-- already-created ped. Character selectors use a local, non-networked clone,
-- so replacing PlayerPedId() (applyModel's job) would be the wrong operation.
exports('ApplyAppearanceToPed', function(ped, model, skin)
    if type(ped) ~= 'number' or ped == 0 or not DoesEntityExist(ped) then
        return false, 'invalid ped'
    end
    if not Shared.isFreemodeModel(model) or GetEntityModel(ped) ~= joaat(model) then
        return false, 'ped model does not match appearance model'
    end
    applySkin(ped, skin, model)
    return true
end)

RegisterCommand('refreshskin', function() applySavedSkin() end, false)

-- Config.interactionMode = 'textui' replaces the target option with kora_lib's
-- "[E] Open <shop>" prompt while the player is inside the shop zone. It is read
-- once at registration, so changing it needs a resource restart.
local textUiShop -- { index, label, handle } while inside a shop zone, else nil

local function hideShopPrompt()
    if textUiShop and textUiShop.handle then
        Kora.textui.hide(textUiShop.handle)
        textUiShop.handle = nil
    end
end

local function showShopPrompt()
    if not textUiShop or activeSession then return end
    hideShopPrompt()
    textUiShop.handle = Kora.textui.show(('Open %s'):format(textUiShop.label), { key = 'E', icon = 'Shirt' })
end

local function registerTextUiShop(index, shop, zone)
    local callbacks = {
        onEnter = function()
            textUiShop = { index = index, label = shop.label }
            showShopPrompt()
        end,
        onExit = function()
            hideShopPrompt()
            textUiShop = nil
        end,
    }

    if zone.points then
        Kora.zones.poly({
            points = zone.points, thickness = zone.thickness, minZ = zone.minZ, maxZ = zone.maxZ,
            onEnter = callbacks.onEnter, onExit = callbacks.onExit,
        })
        return
    end
    Kora.zones.box({
        coords = vector3(shop.coords.x, shop.coords.y, shop.coords.z),
        size = zone.size or Config.shopZoneDefault.size,
        rotation = zone.rotation or shop.coords.w,
        onEnter = callbacks.onEnter, onExit = callbacks.onExit,
    })
end

-- The target is the storefront itself, not a clerk. A ped-bound target dies
-- with the ped: an unstreamed model, a player shoving the clerk out of place,
-- or another resource deleting stray peds all leave the shop silently
-- unopenable, and the entity has to exist at all before anything can be
-- attached to it. A zone is geometry -- it is where the config says it is,
-- always. The optional ped (Config.shopPeds) is therefore pure set dressing
-- and deliberately carries no options of its own.
--
-- Note the shape difference against addEntity/addModel: the zone APIs take ONE
-- opts table with `options` INSIDE it, where addEntity takes the options array
-- as its own positional argument (see kora_target/client/state.lua).
local function registerTargetShop(index, shop, zone)
    local options = {
        {
            label = ('Open %s'):format(shop.label),
            icon = 'Shirt',
            distance = Config.interactDistance,
            onSelect = function() openSession('shop', { shopId = index }) end,
        },
    }
    -- A polygon's centroid can sit inside a wall, so the sprite is anchored on
    -- the shop's own interaction point. drawSprite stays nil by default so
    -- kora_target's global sprites setting decides; true/false force it.
    local spriteCoords = vector3(shop.coords.x, shop.coords.y, shop.coords.z)

    if zone.points then
        exports.kora_target:addPolyZone({
            points = zone.points,
            thickness = zone.thickness,
            minZ = zone.minZ,
            maxZ = zone.maxZ,
            options = options,
            distance = Config.interactDistance,
            spriteCoords = spriteCoords,
            drawSprite = Config.showTargetHints,
        })
        return
    end
    exports.kora_target:addBoxZone({
        -- shop.coords is a vector4 (heading in .w) and addBoxZone only
        -- reads x/y/z off it, so the heading is passed separately as
        -- the box's own rotation rather than being read from coords.
        coords = shop.coords,
        size = zone.size or Config.shopZoneDefault.size,
        rotation = zone.rotation or shop.coords.w,
        options = options,
        distance = Config.interactDistance,
        spriteCoords = spriteCoords,
        drawSprite = Config.showTargetHints,
    })
end

-- A client-local, frozen artist per tattoo shop, only while the player is near.
-- It carries a kora_target "Get tattooed" option that opens the same session as
-- the shop's storefront zone (which stays registered, so both work). While the
-- studio menu is open the artist is faded out so it does not block the camera.
local tattooPeds = {} -- shop index -> { ped = entity, targetId = id | nil }
local tattooPedsFaded = false

local function tattooPedsEnabled()
    local peds = Config.tattoo and Config.tattoo.peds
    return type(peds) == 'table' and peds.enabled == true
end

---@return string? model, table? coords, string? scenario  -- nil when this shop gets no artist
local function tattooPedSpec(shop)
    if shop.service ~= 'tattoo' or shop.tattooPed == false then return nil end
    local peds = Config.tattoo.peds
    local override = type(shop.tattooPed) == 'table' and shop.tattooPed or {}
    local model = override.model or shop.ped or peds.model
    local coords = override.coords or shop.coords
    if type(model) ~= 'string' or not coords then return nil end
    return model, coords, override.scenario or peds.scenario
end

local function applyTattooPedAlpha(ped, faded)
    if not DoesEntityExist(ped) then return end
    if faded then
        SetEntityAlpha(ped, math.max(0, math.min(255, math.floor(tonumber(Config.tattoo.peds.alpha) or 0))), false)
    else
        ResetEntityAlpha(ped)
    end
end

setTattooPedsFaded = function(faded)
    tattooPedsFaded = faded == true and tattooPedsEnabled()
    for _, entry in pairs(tattooPeds) do applyTattooPedAlpha(entry.ped, tattooPedsFaded) end
end

local function removeTattooPed(index)
    local entry = tattooPeds[index]
    if not entry then return end
    tattooPeds[index] = nil
    if entry.targetId then
        pcall(function() exports.kora_target:removeEntity(entry.ped, entry.targetId) end)
    end
    if DoesEntityExist(entry.ped) then DeleteEntity(entry.ped) end
end

local function spawnTattooPed(index, model, coords, scenario)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(25) end
    if not HasModelLoaded(hash) then return end

    -- Shop coords are floor level but a ped is placed by its middle, so find the
    -- ground and stand the artist on it instead of sinking them to the knees.
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local z = coords.z + 1.0
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
    if found then z = groundZ + 1.0 end

    local ped = CreatePed(4, hash, coords.x, coords.y, z, coords.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if ped == 0 or not DoesEntityExist(ped) then return end

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    if type(scenario) == 'string' and scenario ~= '' then TaskStartScenarioInPlace(ped, scenario, 0, true) end

    local entry = { ped = ped }
    tattooPeds[index] = entry
    if tattooPedsFaded then applyTattooPedAlpha(ped, true) end

    -- Text prompt servers open the shop from the zone prompt only.
    if Config.interactionMode == 'textui' then return end

    local ok, targetId = pcall(function()
        return exports.kora_target:addEntity(ped, {
            {
                label = 'Get tattooed',
                icon = 'Pen',
                distance = Config.interactDistance,
                onSelect = function() openSession('shop', { shopId = index }) end,
            },
        }, Config.interactDistance)
    end)
    if ok then entry.targetId = targetId end
end

-- One pass: spawn artists the player is near, delete the ones they left (with
-- a margin so a player on the edge does not flicker one in and out).
local function syncTattooPeds()
    if not tattooPedsEnabled() then
        for index in pairs(tattooPeds) do removeTattooPed(index) end
        return
    end

    local player = GetEntityCoords(PlayerPedId())
    local radius = tonumber(Config.tattoo.peds.scopeRadius) or 40.0
    for index, shop in ipairs(Config.shops) do
        local model, coords, scenario = tattooPedSpec(shop)
        if model then
            local distance = #(player - vector3(coords.x, coords.y, coords.z))
            local entry = tattooPeds[index]
            if entry and (distance > radius + 5.0 or not DoesEntityExist(entry.ped)) then
                removeTattooPed(index)
                entry = nil
            end
            if not entry and distance <= radius then spawnTattooPed(index, model, coords, scenario) end
        end
    end
end

CreateThread(function()
    while true do
        syncTattooPeds()
        Wait(1500)
    end
end)

CreateThread(function()
    local textUiMode = Config.interactionMode == 'textui'
    if textUiMode then
        refreshShopPrompt = showShopPrompt
        Kora.keybind.add({
            name = 'kora_clothing_open_shop',
            description = 'Open the clothing shop you are standing in',
            defaultKey = 'E',
            onPressed = function()
                if not textUiShop or activeSession then return end
                hideShopPrompt()
                openSession('shop', { shopId = textUiShop.index })
            end,
        })
    end

    for index, shop in ipairs(Config.shops) do
        local zone = shop.zone or Config.shopZoneDefault
        if textUiMode then
            registerTextUiShop(index, shop, zone)
        else
            registerTargetShop(index, shop, zone)
        end

        -- An enabled tattoo artist (above) takes the clerk's place at its shop.
        local ownsTattooPed = tattooPedsEnabled() and tattooPedSpec(shop) ~= nil
        if Config.shopPeds and not ownsTattooPed then
            -- The storefront zone above owns the interaction. The clerk is
            -- cosmetic, so keep it client-local and only create it while this
            -- player is near the shop rather than at every shop on startup.
            Kora.entities.createScoped(shop.ped, shop.coords, {
                radius = Config.shopPedScopeRadius,
                freeze = true,
                blockNonTempEvents = true,
            })
        end

        if shop.blip and shop.blip.enabled then
            local blip = Kora.blips.create(shop.coords, shop.blip)
            if blip and not shop.blip.info then
                Kora.blips.setInfo(blip, {
                    title = shop.label,
                    rows = {
                        { kind = 'name', label = 'Service', value = shop.service },
                        { kind = 'wrappedText', value = shop.free and 'This service is free.' or 'Browse and purchase available customisations.' },
                    },
                })
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for index in pairs(tattooPeds) do removeTattooPed(index) end
    if activeSession then
        restoreHudForSession(activeSession)
        restoreRadarForSession(activeSession)
        stopRotate('close')
        Camera.stop()
        stopControlLock()
        SetNuiFocus(false, false)
        FreezeEntityPosition(PlayerPedId(), false)
        -- Put back anything the session bared (tattoo undress, barber hat).
        restoreTemporaryOverride(PlayerPedId())
    end
end)

-- Lets the /c quick toggles (client/quicktoggle.lua) stay out of the fitting room.
if QuickToggle then QuickToggle.sessionActive = function() return activeSession ~= nil end end

-- Deliberately absent in production. Same pattern as kora_target's
-- Config.target.testMode -> Target._testRuntime: lets the standalone smoke
-- suite exercise applySkin's index bounds-checking without a running client.
if Config.testMode then
    QBClothing = QBClothing or {}
    QBClothing._testRuntime = {
        applySkin = applySkin, reapplyColours = reapplyColours, refreshHairVariation = refreshHairVariation,
        currentSkinSnapshot = currentSkinSnapshot, headPayload = headPayload,
        syncTattooPeds = syncTattooPeds, tattooPeds = tattooPeds,
    }
end
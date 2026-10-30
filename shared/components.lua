-- Static GTA V ped drawable-component and prop slot catalogue. Drawable/
-- texture COUNTS are never hardcoded here -- they vary per model and are
-- queried live via GetNumberOfPedDrawableVariations/GetNumberOfPedTextureVariations
-- (client/client.lua), matching how real qb-clothing/illenium-appearance both
-- build their category lists at runtime instead of shipping a fixed catalogue.

Shared = Shared or {}

-- id -> { label, category } -- category groups the NUI's left-rail tabs.
Shared.components = {
    [0]  = { label = 'Face',       category = 'body' },
    [1]  = { label = 'Mask',       category = 'body' },
    [2]  = { label = 'Hair',       category = 'body' },
    [3]  = { label = 'Arms',       category = 'tops' },
    [4]  = { label = 'Legs',       category = 'legs' },
    [5]  = { label = 'Bag',        category = 'accessories' },
    [6]  = { label = 'Shoes',      category = 'shoes' },
    [7]  = { label = 'Accessory',  category = 'accessories' },
    [8]  = { label = 'Undershirt', category = 'tops' },
    [9]  = { label = 'Kevlar',     category = 'tops' },
    [10] = { label = 'Badge',      category = 'accessories' },
    [11] = { label = 'Jackets',    category = 'tops' },
}

-- id -> { label, category, clearable } -- props support "none" (drawable -1),
-- components never do (drawable 0 is always a valid "bare" variation).
Shared.props = {
    [0] = { label = 'Hat',      category = 'accessories', clearable = true },
    [1] = { label = 'Glasses',  category = 'accessories', clearable = true },
    [2] = { label = 'Ears',     category = 'accessories', clearable = true },
    [6] = { label = 'Watch',    category = 'accessories', clearable = true },
    [7] = { label = 'Bracelet', category = 'accessories', clearable = true },
}

Shared.models = {
    male = 'mp_m_freemode_01',
    female = 'mp_f_freemode_01',
}

---@param model string
---@return boolean
function Shared.isFreemodeModel(model)
    return model == Shared.models.male or model == Shared.models.female
end

function Shared.modelGender(model)
    if model == Shared.models.male then return 'male' end
    if model == Shared.models.female then return 'female' end
    return nil
end

function Shared.tattoosFor(model)
    local gender, out = Shared.modelGender(model), {}
    if not gender then return out end
    for _, tattoo in ipairs(Config.tattoos or {}) do
        local overlay = tattoo[gender]
        if type(tattoo.id) == 'string' and type(tattoo.collection) == 'string' and type(overlay) == 'string' and overlay ~= '' then
            out[#out + 1] = { id = tattoo.id, label = tattoo.label or tattoo.id, group = tattoo.group or 'Other', collection = tattoo.collection, overlay = overlay, price = math.max(0, math.floor(tonumber(tattoo.price) or 0)) }
        end
    end
    return out
end

function Shared.tattooById(model, id)
    if type(id) ~= 'string' then return nil end
    for _, tattoo in ipairs(Shared.tattoosFor(model)) do
        if tattoo.id == id then return tattoo end
    end
    return nil
end

-- GTA's hair colouring is INDEXED, never RGB: SetPedHairColor takes two
-- entries from the model's own fixed hair palette and accepts nothing else, so
-- a hair colour is stored as a pair of palette indices (see buildHairPalette
-- in client/client.lua for why there is no free colour picker to be had here).
-- This cap is the coarse anti-garbage bound the SERVER can enforce -- the true
-- palette length is a live-ped query (GetNumHairColors), so the client
-- re-clamps against the real thing before the native call, exactly like it
-- already does for drawable/texture indices.
Shared.maxHairColorIndex = 63

---@param value any
---@return integer -- always a palette index inside [0, Shared.maxHairColorIndex]
function Shared.clampHairColor(value)
    value = tonumber(value)
    -- `value ~= value` is the NaN test: math.floor(NaN) stays NaN and would
    -- reach SetPedHairColor as a non-index.
    if not value or value ~= value then return 0 end
    value = math.floor(value)
    if value < 0 then return 0 end
    if value > Shared.maxHairColorIndex then return Shared.maxHairColorIndex end
    return value
end

-- Head overlays editable beyond the hair component. `style` is the saved head
-- field, so `beard` keeps its original name for old saves; `overlay` is the GTA
-- head overlay index passed to SetPedHeadOverlay. List order is UI order.
Shared.headOverlays = {
    { key = 'facialHair', overlay = 1, style = 'beard', opacity = 'beardOpacity', color = 'beardColor', maxStyle = 28 },
    { key = 'eyebrows', overlay = 2, style = 'eyebrows', opacity = 'eyebrowsOpacity', color = 'eyebrowsColor', maxStyle = 33 },
}

local function clampNumber(value, minimum, maximum, default)
    value = tonumber(value)
    -- `value ~= value` is the NaN test.
    if not value or value ~= value then return default end
    return math.min(maximum, math.max(minimum, value))
end

---Normalises a saved/requested head table. Missing keys (saves from before an
---overlay existed) take their defaults: no style, full opacity, and colour -1,
---which means "follow the hair colour" as facial hair always has.
---@param raw any
---@return table
function Shared.sanitiseHead(raw)
    raw = type(raw) == 'table' and raw or {}
    local head = { skinTone = math.floor(clampNumber(raw.skinTone, 0, 45, 0)) }
    for _, overlay in ipairs(Shared.headOverlays) do
        head[overlay.style] = math.floor(clampNumber(raw[overlay.style], -1, overlay.maxStyle, -1))
        head[overlay.opacity] = math.floor(clampNumber(raw[overlay.opacity], 0, 1, 1) * 100 + 0.5) / 100
        head[overlay.color] = math.floor(clampNumber(raw[overlay.color], -1, Shared.maxHairColorIndex, -1))
    end
    return head
end

---Whether a service may edit one head overlay, read live from
---Config.headOverlays. Creation/admin sessions use `creator`; sessions that
---can edit the hair component (barber, hairdresser) use `barber`. A config
---without the table keeps the original behaviour: creator facial hair only.
---@param policy table Config.services entry
---@param key string 'facialHair' | 'eyebrows'
---@return boolean
function Shared.headOverlayEnabled(policy, key)
    local entry = (Config.headOverlays or {})[key]
    if entry == nil then return policy.all == true and key == 'facialHair' end
    if policy.all then return entry.creator == true end
    for _, id in ipairs(policy.components or {}) do
        if id == 2 then return entry.barber == true end
    end
    return false
end

---Whether the service may see any head control at all.
function Shared.headEditable(policy)
    if policy.all then return true end
    for _, overlay in ipairs(Shared.headOverlays) do
        if Shared.headOverlayEnabled(policy, overlay.key) then return true end
    end
    return false
end

---Applies a requested head onto the current one, keeping every part the
---service may not change (skin tone outside creation, disabled overlays).
---@return table sanitised head
function Shared.mergeHead(policy, current, requested)
    current, requested = Shared.sanitiseHead(current), Shared.sanitiseHead(requested)
    local merged = { skinTone = policy.all and requested.skinTone or current.skinTone }
    for _, overlay in ipairs(Shared.headOverlays) do
        local source = Shared.headOverlayEnabled(policy, overlay.key) and requested or current
        merged[overlay.style], merged[overlay.opacity], merged[overlay.color] = source[overlay.style], source[overlay.opacity], source[overlay.color]
    end
    return merged
end

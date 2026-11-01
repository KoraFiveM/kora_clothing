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

-- Tattoo stacking (Config.tattoo.allowStacking/maxStack/stackPriceMultiplier).
-- A skin's `tattoos` is an ordered list of tattoo ids; stacking simply repeats
-- an id, one entry per instance, and each entry is a separate
-- AddPedDecorationFromHashes call so the overlay renders darker. Read at use
-- time so a live config change applies to the next session.
function Shared.tattooStacking()
    local cfg = type(Config.tattoo) == 'table' and Config.tattoo or {}
    local enabled = cfg.allowStacking ~= false
    local max = math.max(1, math.min(10, math.floor(tonumber(cfg.maxStack) or 3)))
    local multiplier = math.max(0, tonumber(cfg.stackPriceMultiplier) or 1.0)
    return { enabled = enabled, max = enabled and max or 1, priceMultiplier = multiplier }
end

-- Keeps only ids in the model's catalogue and at most `max` instances of each
-- (extra instances are dropped, never trusted). Order is preserved.
function Shared.sanitiseTattoos(model, tattoos)
    local out, counts = {}, {}
    local max = Shared.tattooStacking().max
    for _, id in ipairs(type(tattoos) == 'table' and tattoos or {}) do
        if Shared.tattooById(model, id) and (counts[id] or 0) < max then
            counts[id] = (counts[id] or 0) + 1
            out[#out + 1] = id
        end
    end
    return out
end

function Shared.tattooCounts(tattoos)
    local counts = {}
    for _, id in ipairs(tattoos or {}) do counts[id] = (counts[id] or 0) + 1 end
    return counts
end

-- Price of going from `previous` to `new` (both sanitised). Existing instances
-- and removals are free; every added instance costs the tattoo's price, with
-- instances beyond the first of an id scaled by the stack price multiplier.
function Shared.tattooPriceDiff(model, previous, new)
    local before, after, total = Shared.tattooCounts(previous), Shared.tattooCounts(new), 0
    local multiplier = Shared.tattooStacking().priceMultiplier
    for id, count in pairs(after) do
        local tattoo = Shared.tattooById(model, id)
        for instance = (before[id] or 0) + 1, count do
            local price = tattoo and tattoo.price or 0
            if instance > 1 then price = math.floor(price * multiplier + 0.5) end
            total = total + price
        end
    end
    return total
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

---Whether an overlay is locked to the primary hair colour. Only eyebrows can
---be, via Config.headOverlays.eyebrows.followHairColor (default false: their
---colour is independent). Facial hair has its own palette, which falls back to
---the hair colour only while unset (-1).
---@param key string facialHair | eyebrows
---@return boolean
function Shared.overlayFollowsHair(key)
    local entry = (Config.headOverlays or {})[key]
    return key == 'eyebrows' and type(entry) == 'table' and entry.followHairColor == true
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
        -- A hair-locked overlay stores no colour of its own, so toggling the
        -- option later never resurrects a stale independent colour.
        if Shared.overlayFollowsHair(overlay.key) then merged[overlay.color] = -1 end
    end
    return merged
end

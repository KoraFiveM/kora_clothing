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
    [3]  = { label = 'Torso',      category = 'tops' },
    [4]  = { label = 'Legs',       category = 'legs' },
    [5]  = { label = 'Bag',        category = 'accessories' },
    [6]  = { label = 'Shoes',      category = 'shoes' },
    [7]  = { label = 'Accessory',  category = 'accessories' },
    [8]  = { label = 'Undershirt', category = 'tops' },
    [9]  = { label = 'Kevlar',     category = 'tops' },
    [10] = { label = 'Badge',      category = 'accessories' },
    [11] = { label = 'Torso 2',    category = 'tops' },
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

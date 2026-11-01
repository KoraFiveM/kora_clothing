-- Regression coverage for the spawn-crash fix: SetPedComponentVariation and
-- SetPedPropIndex fault inside the game's own executable (not a catchable Lua
-- error) when given a drawable/texture index the current model/slot doesn't
-- actually have. Server-side sanitiseSkin only clamps to a generous
-- [-1, 999] "not garbage" range (its own comment admits it can't know the
-- real per-model/per-slot cap), and the spawn-time getSkin callback used to
-- skip even that. applySkin (client/client.lua) is the single choke point
-- every caller funnels through, so THIS is where the real bound has to be
-- enforced -- against the live GetNumberOfPed*Variations count, exactly like
-- buildCategoryPayload already queries for the NUI list.
--
-- This exercises real Lua logic (arithmetic bounds-checking against mocked
-- native return values), not FiveM-specific runtime behaviour -- unlike
-- security.lua's source-shape assertions, actually running the clamping code
-- is the only way to catch an off-by-one in it.
local H = dofile('test/harness.lua')

_G.GetCurrentResourceName = function() return 'kora_clothing' end
_G.AddEventHandler = function() end
_G.RegisterNetEvent = function() end
_G.RegisterNUICallback = function() end
_G.CreateThread = function() end -- skip the shop-ped spawn loop entirely
_G.exports = setmetatable({}, {
    __call = function() end, -- bare exports('Name', fn) registration
    __index = function() return function() end end, -- exports.other:fn(...)
})
-- Chunk-load reconcile (mirrors kora_hud's client/bridge/qbcore.lua pattern):
-- client.lua reads the login state bag and calls PlayerId/GetPlayerServerId
-- as soon as it loads, so these need to exist even though this test never
-- drives a login transition. CreateThread above is a no-op stub, so the
-- actual Kora.callback.trigger('qb-clothing:server:getSkin') round trip this
-- would kick off never runs here.
_G.PlayerId = function() return 1 end
_G.GetPlayerServerId = function() return 1 end
_G.LocalPlayer = { state = {} }
_G.AddStateBagChangeHandler = function() end

-- Recorded calls into the natives under test.
local componentCalls, propCalls, clearedProps = {}, {}, {}
_G.SetPedComponentVariation = function(ped, id, drawable, texture, palette)
    componentCalls[#componentCalls + 1] = { id = id, drawable = drawable, texture = texture, palette = palette }
end
_G.SetPedPropIndex = function(ped, id, drawable, texture, attach)
    propCalls[#propCalls + 1] = { id = id, drawable = drawable, texture = texture, attach = attach }
end
_G.ClearPedProp = function(ped, id) clearedProps[#clearedProps + 1] = id end
local hairCalls = {}
_G.SetPedHairColor = function(_, color, highlight)
    hairCalls[#hairCalls + 1] = { color = color, highlight = highlight }
end
-- A deliberately SHORT palette, for the same reason the drawable counts below
-- are small: it makes an index of 40 unambiguously out of the model's real
-- palette even though Shared.clampHairColor's coarse [0, 63] bound accepts it.
_G.GetNumHairColors = function() return 8 end
_G.GetPedHairRgbColor = function(index) return index * 10, index * 10 + 1, index * 10 + 2 end
_G.ClearPedDecorations = function() end
_G.AddPedDecorationFromHashes = function() end
_G.GetHashKey = function(v) return v end
_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end

-- Live per-slot variation counts the fix must respect. Deliberately SMALL
-- (a handful of drawables, not hundreds) so a saved index of, say, 40 is
-- unambiguously out of range -- exactly the shape of a stale/pre-update skin
-- row surviving a wardrobe rework.
local drawableCounts = { [0] = 3, [2] = 3, [3] = 5 } -- component 0 = Face, 2 = Hair, 3 = Torso
local textureCounts = {} -- [id][drawable] = count
textureCounts[0] = { [0] = 2, [1] = 2, [2] = 2 }
textureCounts[2] = { [0] = 2, [1] = 2, [2] = 2 }
textureCounts[3] = { [0] = 4, [1] = 4, [2] = 4, [3] = 4, [4] = 4 }
local propDrawableCounts = { [0] = 4 } -- prop 0 = Hats
local propTextureCounts = { [0] = { [0] = 2, [1] = 2, [2] = 2, [3] = 2 } }

_G.GetNumberOfPedDrawableVariations = function(_, id) return drawableCounts[id] or 0 end
_G.GetNumberOfPedTextureVariations = function(_, id, drawable)
    return (textureCounts[id] or {})[drawable] or 0
end
_G.GetPedDrawableVariation = function(_, id) return id == 2 and 2 or 0 end
_G.GetPedTextureVariation = function(_, id) return id == 2 and 1 or 0 end
_G.GetNumberOfPedPropDrawableVariations = function(_, id) return propDrawableCounts[id] or 0 end
_G.GetNumberOfPedPropTextureVariations = function(_, id, drawable)
    return (propTextureCounts[id] or {})[drawable] or 0
end

dofile('config.lua')
Config.testMode = true
dofile('shared/components.lua')
_G.RegisterCommand = _G.RegisterCommand or function() end
_G.TriggerEvent = _G.TriggerEvent or function() end
dofile('client/client.lua')

local runtime = QBClothing._testRuntime

local function callFor(calls, id)
    for _, c in ipairs(calls) do if c.id == id then return c end end
    return nil
end

local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

-- A colour click does not otherwise touch component 2. Re-applying the live
-- valid hairstyle before its tint is what makes a palette click take effect in
-- GTA's renderer, while keeping the existing style and texture intact.
componentCalls = {}
runtime.refreshHairVariation(1)
local refreshedHair = callFor(componentCalls, 2)
H.ok(refreshedHair ~= nil, 'a hair-colour preview refreshes the current hair drawable first')
H.equal(refreshedHair.drawable, 2, 'the preview refresh keeps the current hair style')
H.equal(refreshedHair.texture, 1, 'the preview refresh keeps the current hair texture')

-- A stale/malformed skin: component 0 (Face) drawable 40 (only 3 exist),
-- component 3 (Torso) texture 99 (only 4 exist for its drawable 1), prop 0
-- (Hats) drawable 999 (only 4 exist) -- exactly what an unsanitised DB row or
-- a "clamped to [-1,999]" value could still carry.
componentCalls, propCalls, clearedProps = {}, {}, {}
runtime.applySkin(1, {
    components = {
        ['0'] = { d = 40, t = 0 },
        ['3'] = { d = 1, t = 99 },
    },
    props = {
        ['0'] = { d = 999, t = 0 },
    },
}, 'mp_m_freemode_01')

local face = callFor(componentCalls, 0)
H.ok(face ~= nil, 'component 0 (Face) still gets set despite the bad drawable')
H.equal(face.drawable, 0, 'an out-of-range drawable (40, only 3 exist) falls back to 0 instead of crashing the native')

local torso = callFor(componentCalls, 3)
H.ok(torso ~= nil, 'component 3 (Torso) still gets set')
H.equal(torso.drawable, 1, 'a VALID drawable is left untouched')
H.equal(torso.texture, 0, 'an out-of-range texture (99, only 4 exist for drawable 1) falls back to 0')

H.ok(not callFor(propCalls, 0), 'an out-of-range prop drawable (999, only 4 exist) must not reach SetPedPropIndex')
H.ok(contains(clearedProps, 0), 'that prop is cleared instead')

-- A fully valid skin must pass through completely unchanged -- the fix must
-- not perturb legitimate, in-range selections.
componentCalls, propCalls, clearedProps = {}, {}, {}
runtime.applySkin(1, {
    components = { ['0'] = { d = 2, t = 1 } },
    props = { ['0'] = { d = 2, t = 1 } },
}, 'mp_m_freemode_01')

local face2 = callFor(componentCalls, 0)
H.equal(face2.drawable, 2, 'a valid drawable at the top of its range is preserved')
H.equal(face2.texture, 1, 'a valid texture is preserved')

local hat = callFor(propCalls, 0)
H.ok(hat ~= nil, 'a valid, in-range prop reaches SetPedPropIndex')
H.equal(hat.drawable, 2, 'a valid prop drawable is preserved')
H.equal(hat.texture, 1, 'a valid prop texture is preserved')
H.ok(not contains(clearedProps, 0), 'a valid, specified prop is not cleared')
-- Props NOT mentioned in this skin (1, 2, 6, 7 -- see Shared.props) are
-- correctly cleared; this is pre-existing behaviour, not part of this fix.
H.ok(contains(clearedProps, 1) and contains(clearedProps, 2), 'unspecified prop slots are still cleared as before')

-- A component slot with ZERO variations for this model (e.g. a slot the
-- current model simply doesn't have) must be skipped entirely, not forced
-- to a "drawable 0" that GetNumberOfPedDrawableVariations already said
-- doesn't exist either.
componentCalls = {}
runtime.applySkin(1, { components = { ['1'] = { d = 5, t = 0 } } }, 'mp_m_freemode_01') -- component 1 has 0 in drawableCounts
H.equal(#componentCalls, 0, 'a component with zero variations for this model is never set')

-- Non-numeric/garbage entries (a malformed JSON blob) must not error or
-- reach the native with a non-number argument.
componentCalls, propCalls = {}, {}
local ok = pcall(runtime.applySkin, 1, {
    components = { ['0'] = { d = 'not-a-number', t = {} } },
    props = { ['0'] = { d = 'also-bad' } },
}, 'mp_m_freemode_01')
H.ok(ok, 'garbage (non-numeric) index values do not error')
H.equal(componentCalls[1].drawable, 0, 'a non-numeric drawable falls back to 0')
H.equal(componentCalls[1].texture, 0, 'a non-numeric texture falls back to 0')
H.equal(#propCalls, 0, 'a non-numeric prop drawable never reaches SetPedPropIndex')

-- --- hair colour: a pair of PALETTE INDICES, not RGB ---
--
-- SetPedHairColor takes entries from the model's own fixed hair palette, so an
-- index past its end is an out-of-palette read, not a "no colour" sentinel the
-- way prop drawable -1 is. Shared.clampHairColor is the coarse bound the
-- server can enforce without a live ped; applySkin has to narrow that to the
-- palette this model actually has (GetNumHairColors), exactly as it already
-- narrows drawable indices to GetNumberOfPedDrawableVariations.
H.equal(Shared.clampHairColor(3), 3, 'an in-range hair colour index is preserved')
H.equal(Shared.clampHairColor(-1), 0, 'a negative hair colour index is not a sentinel -- it clamps to 0')
H.equal(Shared.clampHairColor(999), Shared.maxHairColorIndex, 'an index past the palette clamps to the last entry, never wraps')
H.equal(Shared.clampHairColor('not-a-number'), 0, 'garbage never reaches SetPedHairColor as a non-index')
H.equal(Shared.clampHairColor(nil), 0, 'a missing hair colour defaults to index 0')
H.equal(Shared.clampHairColor(4.7), 4, 'a fractional index is floored, not rounded up past the palette')
H.equal(Shared.clampHairColor(0 / 0), 0, 'NaN survives math.floor, so it is rejected before the clamp')

hairCalls = {}
runtime.applySkin(1, { hairColor = 3, hairHighlight = 5 }, 'mp_m_freemode_01')
H.equal(#hairCalls, 1, 'applySkin always sets a hair colour, so a saved look cannot inherit the previous ped\'s')
H.equal(hairCalls[1].color, 3, 'an in-palette primary hair colour is applied unchanged')
H.equal(hairCalls[1].highlight, 5, 'an in-palette highlight is applied unchanged')

-- 40 passes Shared.clampHairColor's [0, 63] bound but this model has only 8
-- palette entries -- exactly the shape of a skin row saved against a model
-- with a longer palette.
hairCalls = {}
runtime.applySkin(1, { hairColor = 40, hairHighlight = 7 }, 'mp_m_freemode_01')
H.equal(hairCalls[1].color, 0, 'an index inside the shared bound but outside THIS palette falls back to 0')
H.equal(hairCalls[1].highlight, 7, 'the last real palette entry is still usable')

hairCalls = {}
local hairOk = pcall(runtime.applySkin, 1, { hairColor = {}, hairHighlight = 'brown' }, 'mp_m_freemode_01')
H.ok(hairOk, 'garbage hair colour values do not error')
H.equal(hairCalls[1].color, 0, 'a table hair colour falls back to index 0')
H.equal(hairCalls[1].highlight, 0, 'a string highlight falls back to index 0')

H.finish()

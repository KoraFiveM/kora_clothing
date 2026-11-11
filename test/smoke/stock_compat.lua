-- Stock qb-clothing compat: loadOutfit overlay (never swaps the model),
-- loadPlayerClothing, qb-clothes:loadSkin, exports, openMenu, radialmenu
-- aliases, onMenuClose, plus the own-data-only server handlers.
local H = dofile('test/harness.lua')

local handlers, commands, exported, triggered, notices = {}, {}, {}, {}, {}
_G.GetCurrentResourceName = function() return 'kora_clothing' end
_G.AddEventHandler = function() end
_G.RegisterNetEvent = function(name, fn) if fn then handlers[name] = fn end end
_G.RegisterNUICallback = function() end
_G.RegisterCommand = function(name, fn) commands[name] = fn end
_G.CreateThread = function() end
_G.TriggerEvent = function(name, ...) triggered[#triggered + 1] = { name = name, args = { ... } } end
_G.exports = setmetatable({}, {
    __call = function(_, name, fn) exported[name] = fn end,
    __index = function() return function() end end,
})
_G.PlayerId = function() return 1 end
_G.GetPlayerServerId = function() return 1 end
_G.LocalPlayer = { state = {} }
_G.AddStateBagChangeHandler = function() end
_G.joaat = function(v) return v end
_G.GetHashKey = _G.joaat
local vec = {
    __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, getmetatable(a)) end,
    __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
}
_G.vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, vec) end
_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.json = { decode = function(s) return load('return ' .. s)() end }

local model = 'mp_m_freemode_01'
local modelSets, componentCalls, propCalls, cleared = 0, {}, {}, {}
_G.GetEntityModel = function() return model end
_G.DoesEntityExist = function(ped) return ped ~= 99 end
_G.SetPlayerModel = function() modelSets = modelSets + 1 end
_G.SetModelAsNoLongerNeeded = function() end
_G.SetPedDefaultComponentVariation = function() end
_G.Kora = {
    stream = { loadModel = function() return true end },
    notify = { send = function(p) notices[#notices + 1] = p end },
}
_G.PlayerPedId = function() return 1 end
_G.SetPedComponentVariation = function(ped, id, d, t) componentCalls[#componentCalls + 1] = { ped = ped, id = id, d = d, t = t } end
_G.SetPedPropIndex = function(ped, id, d, t) propCalls[#propCalls + 1] = { ped = ped, id = id, d = d, t = t } end
_G.ClearPedProp = function(_, id) cleared[#cleared + 1] = id end
_G.SetPedHairColor = function() end
_G.GetNumHairColors = function() return 64 end
_G.ClearPedDecorations = function() end
_G.AddPedDecorationFromHashes = function() end
_G.GetNumberOfPedDrawableVariations = function() return 50 end
_G.GetNumberOfPedTextureVariations = function() return 4 end
_G.GetNumberOfPedPropDrawableVariations = function() return 50 end
_G.GetNumberOfPedPropTextureVariations = function() return 4 end
_G.GetPedDrawableVariation = function() return 0 end
_G.GetPedTextureVariation = function() return 0 end

dofile('config.lua')
Config.testMode = true
dofile('shared/components.lua')
local quickRuns = {}
QuickToggle = { run = function(word) quickRuns[#quickRuns + 1] = word end }
dofile('client/client.lua')

local function find(calls, id)
    for _, c in ipairs(calls) do if c.id == id then return c end end
end
local function has(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

-- loadOutfit: stock payload overlays, never switches the model.
H.ok(handlers['qb-clothing:client:loadOutfit'], 'loadOutfit handler registered')
handlers['qb-clothing:client:loadOutfit']({ outfitData = {
    bag = { item = 7, texture = 1 }, ['t-shirt'] = { item = 4, texture = 2 }, accessory = { item = 13, texture = 0 },
    hat = { item = 5, texture = 1 }, glass = { item = -1, texture = 0 }, watch = { item = 99, texture = 0 },
}, outfitName = 'Work' })
H.equal(modelSets, 0, 'stock loadOutfit never changes the player model')
H.equal(find(componentCalls, 5).d, 7, 'bag item applied to component 5')
H.equal(find(componentCalls, 8).t, 2, 't-shirt applied to component 8')
H.equal(find(componentCalls, 7).d, 13, 'accessory applied to component 7')
H.equal(find(propCalls, 0).d, 5, 'hat applied as prop 0')
H.ok(has(cleared, 1), 'glass item -1 clears prop 1')
H.ok(not find(propCalls, 6) and not has(cleared, 6), 'out-of-range watch is skipped')
H.ok(not find(componentCalls, 4), 'keys absent from the payload leave the ped untouched')
H.equal(#notices, 1, 'outfitName notifies')

local setBefore = modelSets
handlers['qb-clothing:client:loadOutfit']({ outfitData = '{ pants = { item = 3, texture = 0 } }' })
H.equal(find(componentCalls, 4).d, 3, 'a JSON string outfitData is decoded')
handlers['qb-clothing:client:loadOutfit']({})
handlers['qb-clothing:client:loadOutfit']({ outfitData = 5 })
H.equal(modelSets, setBefore, 'a payload with neither outfitData nor model changes nothing')

-- Existing {model, skin} path still switches model.
model = 'mp_f_freemode_01'
handlers['qb-clothing:client:loadOutfit']({ model = 'mp_m_freemode_01', skin = { components = {}, props = {} } })
H.equal(modelSets, setBefore + 1, '{model, skin} still applies the model')
handlers['qb-clothing:client:loadOutfit']({ model = 'a_c_cat_01', skin = {} })
H.equal(modelSets, setBefore + 1, 'a non-freemode model is refused')
model = 'mp_m_freemode_01'

-- loadPlayerClothing on a given ped, guarded.
local stockSkin = {
    face = { item = 3, texture = 4 }, pants = { item = 6, texture = 1 }, hair = { item = 2, texture = 5 },
    eyebrows = { item = 1, texture = 2 }, beard = { item = -1, texture = 0 }, hat = { item = 4, texture = 0 },
}
componentCalls, propCalls, cleared = {}, {}, {}
handlers['qb-clothing:client:loadPlayerClothing'](stockSkin, 50)
local pantsCall = find(componentCalls, 4)
H.equal(pantsCall.ped, 50, 'loadPlayerClothing targets the given ped')
H.equal(pantsCall.d, 6, 'stock pants converted')
H.equal(find(propCalls, 0).d, 4, 'stock hat converted to a prop')
componentCalls = {}
handlers['qb-clothing:client:loadPlayerClothing'](stockSkin, 99)
H.equal(#componentCalls, 0, 'a non-existent ped is refused')
handlers['qb-clothing:client:loadPlayerClothing'](stockSkin)
H.equal(find(componentCalls, 4).ped, 1, 'a missing ped defaults to the player ped')

-- qb-clothes:loadSkin
componentCalls = {}
handlers['qb-clothes:loadSkin'](true)
H.equal(#componentCalls, 0, 'isNew=true applies nothing')
handlers['qb-clothes:loadSkin'](false, 'a_c_cat_01', stockSkin)
H.equal(#componentCalls, 0, 'a non-freemode model is refused')
handlers['qb-clothes:loadSkin'](false, 'mp_m_freemode_01', stockSkin)
H.equal(find(componentCalls, 4).d, 6, 'stock-format skin applied via loadPlayerClothing')
componentCalls = {}
handlers['qb-clothes:loadSkin'](false, 'mp_m_freemode_01', { components = { ['4'] = { d = 8, t = 0 } }, props = {} })
H.equal(find(componentCalls, 4).d, 8, 'kora-format skin applied directly')

-- exports, commands
H.ok(exported.reloadSkin and exported.IsCreatingCharacter and exported.getOutfits, 'stock exports registered')
H.equal(exported.IsCreatingCharacter(), false, 'IsCreatingCharacter is false outside a session')
H.ok(commands.refreshskin, 'refreshskin command registered')

-- radialmenu aliases
handlers['qb-radialmenu:ToggleClothing']({ id = 'Top' })
handlers['qb-radialmenu:ToggleClothing']('Neck')
handlers['qb-radialmenu:ToggleProps']('Ear')
handlers['qb-radialmenu:ToggleClothing']('hair')
handlers['qb-radialmenu:ResetClothing']()
handlers['qb-clothing:client:adjustfacewear'](4)
handlers['qb-clothing:client:adjustfacewear'](99)
H.equal(table.concat(quickRuns, ','), 'shirt,chain,ears,reset,mask', 'radialmenu/adjustfacewear map onto quick toggles; unknown ids ignored')

-- openMenu with no context resolves the nearest shop (rejects when too far).
H.ok(handlers['qb-clothing:client:openMenu'], 'openMenu handler registered')
notices = {}
_G.GetEntityCoords = function() return vector3(100000.0, 100000.0, 0.0) end
handlers['qb-clothing:client:openMenu']()
H.equal(#notices, 1, 'openMenu with no context uses the nearest-shop path and reports when no shop is near')

-- Server handlers: own data only.
local serverHandlers, callbacks, clientEvents, deleted = {}, {}, {}, {}
local citizen = { [1] = 'CID1', [2] = 'CID2' }
local outfits = { CID1 = { { id = 7, outfitname = 'A', model = 'mp_m_freemode_01', skin = '{}' } }, CID2 = {} }
local savedSkin = { CID1 = { model = 'mp_m_freemode_01', skin = '{}' } }
_G.source = nil
_G.RegisterNetEvent = function(name, fn) if fn then serverHandlers[name] = fn end end
_G.AddEventHandler = function() end
_G.AddStateBagChangeHandler = function() end
_G.TriggerClientEvent = function(name, target, ...) clientEvents[#clientEvents + 1] = { name = name, target = target, args = { ... } } end
_G.GetGameTimer = function() return 1000 end
_G.GetPlayerName = function() return 'x' end
_G.json = { decode = function() return {} end, encode = function() return '{}' end }
local core = { getPlayerData = function(_, src, keys) if keys[1] == 'citizenid' then return citizen[src] end return { gender = 0 } end }
_G.exports = setmetatable({ kora_core = core }, { __call = function() end })
_G.Kora = {
    events = { register = function() end },
    callback = { register = function(name, fn) callbacks[name] = fn end },
    sql = {
        query = function(q, args) if q:find('playeroutfits', 1, true) then return outfits[args[1]] or {} end return {} end,
        single = function(q, args)
            if q:find('playerskins', 1, true) then return savedSkin[args[1]] end
            for _, row in ipairs(outfits[args[1]] or {}) do if row.id == args[2] then return row end end
        end,
        scalar = function() return 0 end,
        execute = function(q, args) deleted[#deleted + 1] = args; return 1 end,
    },
}
dofile('server/server.lua')

local rows = callbacks['qb-clothing:server:getOutfits'](1)
H.equal(#rows, 1, 'getOutfits returns the caller\'s own outfits')
H.equal(rows[1].outfitId, '7', 'getOutfits exposes outfitId for removeOutfit')
H.equal(#callbacks['qb-clothing:server:getOutfits'](2), 0, 'getOutfits never returns another citizen\'s outfits')
H.equal(#callbacks['qb-clothing:server:getOutfits'](3), 0, 'unknown source gets nothing')

_G.source = 2
serverHandlers['qb-clothing:server:removeOutfit']('A', '7')
H.equal(#deleted, 0, 'removeOutfit cannot delete another citizen\'s outfit')
_G.source = 1
serverHandlers['qb-clothing:server:removeOutfit']('WRONG', '7')
H.equal(#deleted, 0, 'removeOutfit requires the matching name')
_G.GetGameTimer = function() return 10000 end
serverHandlers['qb-clothing:server:removeOutfit']('A', '7')
H.equal(#deleted, 1, 'removeOutfit deletes the caller\'s own outfit')
H.equal(deleted[1][1], 'CID1', 'delete is scoped to the caller\'s citizenid')

clientEvents = {}
serverHandlers['qb-clothes:loadPlayerSkin']()
H.equal(#clientEvents, 1, 'loadPlayerSkin replies once')
H.equal(clientEvents[1].target, 1, 'loadPlayerSkin replies only to the caller')
H.equal(clientEvents[1].name, 'qb-clothes:loadSkin', 'loadPlayerSkin sends qb-clothes:loadSkin')
H.equal(clientEvents[1].args[1], false, 'saved skin flagged as existing')
_G.GetGameTimer = function() return 10100 end
serverHandlers['qb-clothes:loadPlayerSkin']()
H.equal(#clientEvents, 1, 'loadPlayerSkin is rate limited')
_G.source = 2
serverHandlers['qb-clothes:loadPlayerSkin']()
H.equal(clientEvents[2].args[1], true, 'a citizen without a saved skin gets isNew=true')

H.finish()

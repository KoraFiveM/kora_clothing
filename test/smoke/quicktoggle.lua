-- /c <part> quick toggles: remove, restore exactly, stale-change protection,
-- aliases, blocked states, usage, visor pairs, disabled feature.
local H = dofile('test/harness.lua')

local commands, messages = {}, {}
local suggestions = {}
_G.RegisterCommand = function(name, fn) commands[name] = fn end
_G.AddEventHandler = function() end
_G.TriggerEvent = function(name, ...) if name == 'chat:addSuggestion' then suggestions[#suggestions + 1] = { ... } end end
_G.GetCurrentResourceName = function() return 'kora_clothing' end
_G.Kora = { notify = { send = function(p) messages[#messages + 1] = p end } }
_G.joaat = function(v) return v end
_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.PlayerPedId = function() return 1 end
local model = 'mp_m_freemode_01'
_G.GetEntityModel = function() return model end
local dead, inVehicle, cuffed = false, false, false
_G.IsEntityDead = function() return dead end
_G.IsPedInAnyVehicle = function() return inVehicle end
_G.GetResourceState = function() return 'started' end
_G.exports = setmetatable({}, { __index = function() return { isHandcuffed = function() return cuffed end } end })
local now = 10000
_G.GetGameTimer = function() return now end
_G.Wait = function() end
_G.DoesAnimDictExist = function() return true end
_G.RequestAnimDict = function() end
_G.HasAnimDictLoaded = function() return true end
local anims = 0
_G.TaskPlayAnim = function() anims = anims + 1 end

local comps, props = {}, {}
local function dress()
    comps = {}
    for id = 0, 11 do comps[id] = { d = 30 + id, t = 2, p = 1 } end
    props = { [0] = { d = 5, t = 1 }, [1] = { d = 3, t = 0 } }
end
_G.GetNumberOfPedDrawableVariations = function() return 200 end
_G.GetNumberOfPedTextureVariations = function() return 10 end
_G.GetNumberOfPedPropDrawableVariations = function() return 100 end
_G.GetNumberOfPedPropTextureVariations = function() return 10 end
_G.GetPedDrawableVariation = function(_, id) return comps[id].d end
_G.GetPedTextureVariation = function(_, id) return comps[id].t end
_G.GetPedPaletteVariation = function(_, id) return comps[id].p end
_G.SetPedComponentVariation = function(_, id, d, t, p) comps[id] = { d = d, t = t, p = p } end
_G.GetPedPropIndex = function(_, id) return props[id] and props[id].d or -1 end
_G.GetPedPropTextureIndex = function(_, id) return props[id] and props[id].t or 0 end
_G.SetPedPropIndex = function(_, id, d, t) props[id] = { d = d, t = t } end
_G.ClearPedProp = function(_, id) props[id] = nil end

dofile('shared/components.lua')
dofile('config.lua')
Config.quickToggle.visor.male = { [5] = 6 }
dress()
dofile('client/quicktoggle.lua')
local function use(word) messages = {}; now = now + 5000; commands.c(0, { word }) end
local function last() return messages[#messages] and messages[#messages].message or '' end

H.ok(commands.c, '/c registered from Config')
H.equal(suggestions[1][1], '/c', 'chat suggestion registered')
H.ok(suggestions[1][3][1].help:find('vest', 1, true) and suggestions[1][3][1].help:find('visor', 1, true), 'suggestion lists parts')

-- vest: remove then restore exactly
comps[9] = { d = 7, t = 3, p = 1 }
use('vest')
H.equal(comps[9].d, 0, 'vest removed'); H.equal(anims, 1, 'animation played')
use('vest')
H.equal(comps[9].d, 7, 'vest drawable restored'); H.equal(comps[9].t, 3, 'vest texture restored')

-- shirt covers undershirt + arms; alias top
use('top')
H.equal(comps[11].d, 15, 'jacket removed'); H.equal(comps[8].d, 15, 'undershirt removed'); H.equal(comps[3].d, 15, 'arms bare')
use('shirt')
H.equal(comps[11].d, 41, 'jacket restored'); H.equal(comps[8].d, 38, 'undershirt restored'); H.equal(comps[3].d, 33, 'arms restored')

-- props: hat via alias helmet
use('helmet'); H.equal(props[0], nil, 'hat removed')
use('hat'); H.equal(props[0].d, 5, 'hat restored'); H.equal(props[0].t, 1, 'hat texture restored')

-- female gets its own naked values
model = 'mp_f_freemode_01'; dress()
use('pants'); H.equal(comps[4].d, 15, 'female pants value'); use('pants')
use('shoes'); H.equal(comps[6].d, 35, 'female shoes value'); use('shoes')
model = 'mp_m_freemode_01'; dress()

-- stale: player changed the item meanwhile -> do not restore old data
use('pants'); H.equal(comps[4].d, 21, 'male pants nothing value')
comps[4] = { d = 77, t = 0, p = 0 } -- menu changed it
use('pants')
H.equal(comps[4].d, 21, 'stale memory not restored over the change; treated as fresh removal')
use('pants'); H.equal(comps[4].d, 77, 'and the new item is what comes back')

-- already bare
dress(); comps[9].d = 0
use('vest'); H.ok(last():find('not wearing', 1, true), 'bare part says so')

-- model changed in between: nothing restored
dress(); use('glasses'); H.equal(props[1], nil, 'glasses removed')
model = 'mp_f_freemode_01'; dress(); props[1] = nil
use('glasses'); H.equal(props[1], nil, 'different ped model: stale memory not applied')
model = 'mp_m_freemode_01'; dress()

-- reset restores everything
use('mask'); use('bag'); use('watch') -- watch prop slot 6 absent: not worn
comps[1].d = 4; dress(); comps[1].d = 4; comps[5].d = 9
use('mask'); use('bag')
H.equal(comps[1].d, 0, 'mask removed'); H.equal(comps[5].d, 0, 'bag removed')
use('reset')
H.equal(comps[1].d, 4, 'reset restores mask'); H.equal(comps[5].d, 9, 'reset restores bag')
use('reset'); H.ok(last():find('Nothing to put back', 1, true), 'reset with nothing worn removed')

-- visor
dress(); use('visor'); H.equal(props[0].d, 6, 'visor flipped'); use('visor'); H.equal(props[0].d, 5, 'visor flipped back')
props[0].d = 8; use('visor'); H.ok(last():find('no visor', 1, true), 'no visor variant message')
props[0] = nil; use('visor'); H.ok(last():find('not wearing', 1, true), 'visor without hat')

-- usage
dress(); use(nil); H.ok(last():find('Usage: /c', 1, true), 'no argument shows usage')
use('banana'); H.ok(last():find('Usage: /c', 1, true) and messages[1].type == 'error', 'invalid argument shows usage')

-- blocked states
dead = true; use('hat'); H.ok(props[0], 'blocked while dead'); dead = false
cuffed = true; use('hat'); H.ok(props[0], 'blocked while cuffed'); cuffed = false
inVehicle = true; anims = 0; use('hat'); H.equal(props[0], nil, 'allowed in vehicle'); H.equal(anims, 0, 'no animation in vehicle'); use('hat'); inVehicle = false
QuickToggle.sessionActive = function() return true end
use('hat'); H.ok(props[0], 'blocked while fitting room open'); QuickToggle.sessionActive = nil

-- cooldown
messages = {}; now = now + 100000; commands.c(0, { 'hat' }); commands.c(0, { 'hat' }); H.equal(props[0], nil, 'second use inside cooldown ignored')
now = now + 100000; commands.c(0, { 'hat' }); H.equal(props[0].d, 5, 'after cooldown it restores')

-- animations off
Config.quickToggle.animations = false; anims = 0; use('hat'); H.equal(anims, 0, 'animations can be turned off'); use('hat')

-- fitting room session forgets memory
use('vest'); QuickToggle.forget(); dress(); use('vest'); H.equal(comps[9].d, 0, 'forgotten memory: fresh removal')

-- disabled feature registers nothing
commands = {}; suggestions = {}
Config.quickToggle.enabled = false
dofile('client/quicktoggle.lua')
H.equal(commands.c, nil, 'disabled: no command'); H.equal(#suggestions, 0, 'disabled: no suggestion')

H.finish()

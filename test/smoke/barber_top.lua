-- Preview clothing switches (Config.ui.clothingToggles: Hat, Shirt, Pants,
-- Shoes) in the barber / hairdresser menu: preview only, restored on every way
-- out of the menu. Also the open path: refused with a message while downed, and
-- a session left without its screen is cleared instead of blocking every open.
local H = dofile('test/harness.lua')

local netEvents, nuiCallbacks, stopHandlers, threads, messages, triggered, notices = {}, {}, {}, {}, {}, {}, {}
_G.RegisterNetEvent = function(name, fn) netEvents[name] = fn end
_G.AddEventHandler = function(name, fn) if name == 'onResourceStop' then stopHandlers[#stopHandlers + 1] = fn end end
_G.RegisterNUICallback = function(name, fn) nuiCallbacks[name] = fn end
_G.CreateThread = function(fn) threads[#threads + 1] = fn end
_G.GetCurrentResourceName = function() return 'kora_clothing' end
_G.exports = setmetatable({}, { __call = function() end, __index = function() return function() end end })
_G.PlayerId = function() return 1 end
_G.GetPlayerServerId = function() return 1 end
_G.LocalPlayer = { state = {} }
_G.AddStateBagChangeHandler = function() end
_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.PlayerPedId = function() return 1 end
_G.GetEntityModel = function() return 'mp_m_freemode_01' end
_G.joaat = function(value) return value end
_G.FreezeEntityPosition = function() end
_G.SetNuiFocus = function() end
local nuiFocused = true
_G.IsNuiFocused = function() return nuiFocused end
_G.SendNUIMessage = function(message) messages[#messages + 1] = message end
local cameraZone
_G.Camera = { start = function() end, stop = function() end, setZone = function(zone) cameraZone = zone end, setCategory = function() end, currentZone = function() return cameraZone or 'full' end }
_G.KoraTheme = { refresh = function() end }
_G.GetResourceState = function() return 'stopped' end
_G.IsRadarHidden = function() return false end
_G.DisplayRadar = function() end
_G.DisableAllControlActions = function() end
_G.EnableControlAction = function() end
_G.Wait = function() end
_G.SetPedHairColor = function() end
_G.GetNumHairColors = function() return 64 end
_G.ClearPedDecorations = function() end
local dead = false
_G.IsEntityDead = function() return dead end
_G.GetPedHairRgbColor = function() return 10, 10, 10 end

-- A fake freemode ped: every component/prop slot with a current value.
local comps, props = {}, {}
local function dress()
    comps = {}
    for id = 0, 11 do comps[id] = { d = 30 + id, t = 2 } end
    props = { [0] = { d = 5, t = 1 }, [1] = { d = 3, t = 0 } }
end
_G.GetNumberOfPedDrawableVariations = function() return 200 end
_G.GetNumberOfPedTextureVariations = function() return 10 end
_G.GetNumberOfPedPropDrawableVariations = function() return 100 end
_G.GetNumberOfPedPropTextureVariations = function() return 10 end
_G.GetPedDrawableVariation = function(_, id) return comps[id].d end
_G.GetPedTextureVariation = function(_, id) return comps[id].t end
_G.SetPedComponentVariation = function(_, id, d, t) comps[id] = { d = d, t = t } end
_G.GetPedPropIndex = function(_, id) return props[id] and props[id].d or -1 end
_G.GetPedPropTextureIndex = function(_, id) return props[id] and props[id].t or 0 end
_G.SetPedPropIndex = function(_, id, d, t) props[id] = { d = d, t = t } end
_G.ClearPedProp = function(_, id) props[id] = nil end

local function sameAs(original, label)
    for id = 0, 11 do
        H.equal(comps[id].d, original[id].d, label .. ': component ' .. id .. ' drawable')
        H.equal(comps[id].t, original[id].t, label .. ': component ' .. id .. ' texture')
    end
    H.equal(props[0] and props[0].d, 5, label .. ': hat back')
    H.equal(props[0] and props[0].t, 1, label .. ': hat texture back')
    H.equal(props[1] and props[1].d, 3, label .. ': glasses back')
end

-- kora_lib's cache reports the death edge; the menu reacts to it instead of polling.
local cacheHandlers = {}
local outfitSkin
_G.Kora = {
    notify = { send = function(notice) notices[#notices + 1] = notice end },
    events = { trigger = function(name, ...) triggered[#triggered + 1] = { name = name, args = { ... } }; return true end },
    cache = {
        isDead = function() return dead end,
        onChange = function(key, fn) cacheHandlers[key] = fn end,
    },
    callback = { trigger = function() return 'mp_m_freemode_01', outfitSkin end },
}
_G.Kora = _G.Kora

dofile('config.lua')
dofile('shared/components.lua')
_G.RegisterCommand = _G.RegisterCommand or function() end
_G.TriggerEvent = _G.TriggerEvent or function() end
dofile('client/client.lua')

local function snapshotOriginal()
    local original, skin = {}, { components = {}, props = {} }
    for id = 0, 11 do
        original[id] = { d = comps[id].d, t = comps[id].t }
        skin.components[tostring(id)] = { d = comps[id].d, t = comps[id].t }
    end
    for id, prop in pairs(props) do skin.props[tostring(id)] = { d = prop.d, t = prop.t } end
    return original, skin
end

local function open(service, keepDressing)
    if not keepDressing then dress() end
    messages, triggered, threads = {}, {}, {}
    local original, skin = snapshotOriginal()
    netEvents['kora_clothing:client:openSession']({ mode = 'shop', service = service or 'tattoo', model = GetEntityModel(), skin = skin, tattoos = {} })
    return original, skin
end
local function openMessage()
    for _, message in ipairs(messages) do if message.action == 'kora_clothing:nui:open' then return message.data end end
end
local function call(name, data)
    local reply
    nuiCallbacks[name](data, function(value) reply = value end)
    return reply
end
local function toggle(id, removed) return call('kora_clothing:nui:setClothingToggle', { id = id, removed = removed }) end
local function stateOf(list, id)
    for _, entry in ipairs(list or {}) do if entry.id == id then return entry.removed end end
end
local function ids(list)
    local out = {}
    for _, entry in ipairs(list or {}) do out[#out + 1] = entry.id end
    return table.concat(out, ',')
end
local function close(cancelled) netEvents['kora_clothing:client:closeSession']({ ok = true, cancelled = cancelled }) end

local function topIs(expected, label)
    for _, id in ipairs({ 3, 8, 11 }) do
        H.equal(comps[id].d, expected and 15 or 30 + id, label .. ': component ' .. id)
    end
end

-- Menu text: locales/en.json supplies the defaults, kora_lib's Kora.lang a translation.
_G.LoadResourceFile = function() return '{}' end
_G.json = { decode = function() return { ui = { color = 'Color', none = 'None' } } end }
_G.Kora.lang = function(key) if key == 'ui.none' then return 'Ninguno' end return key end

-- Defaults: on, for barbers and hairdressers, all four switches.
local cfg = Config.ui.clothingToggles
H.equal(cfg.enabled, true)
H.equal(table.concat(cfg.services, ','), 'barber,hairdresser')
H.equal(cfg.items.hat and cfg.items.shirt and cfg.items.pants and cfg.items.shoes, true)
H.equal(Config.ui.barberTopToggle, nil, 'the shirt-only option is replaced')

local original = open('barber')
local data = openMessage()
H.equal(ids(data.clothingToggles), 'hat,shirt,pants,shoes', 'barber gets the four switches, in order')
H.equal(stateOf(data.clothingToggles, 'hat'), true, 'the barber already took the hat off')
H.equal(stateOf(data.clothingToggles, 'shirt'), false)
H.equal(props[0], nil, 'hat off for the cut')
H.equal(data.undress, nil, 'the tattoo toolbar is not sent to barbers')
H.equal(data.topToggle, nil, 'the old shirt button is gone')
topIs(false, 'dressed')
H.equal(data.strings.color, 'Color', 'English default reads Color')
H.equal(data.strings.none, 'Ninguno', 'a translation replaces the default')

-- Each switch takes its item off and puts the real one back.
local reply = toggle('shirt', true)
H.equal(reply.ok, true)
H.equal(stateOf(reply.toggles, 'shirt'), true)
topIs(true, 'shirt off')
H.equal(comps[4].d, original[4].d, 'pants untouched')
H.equal(comps[2].d, original[2].d, 'hair untouched')
reply = toggle('shirt', false)
H.equal(stateOf(reply.toggles, 'shirt'), false)
topIs(false, 'shirt back on')
toggle('shirt', true); toggle('shirt', true); toggle('shirt', false)
topIs(false, 'off twice then on once keeps the real original')
toggle('pants', true)
H.equal(comps[4].d, 21, 'male pants off')
toggle('shoes', true)
H.equal(comps[6].d, 34, 'male shoes off')
toggle('pants', false); toggle('shoes', false)
H.equal(comps[4].d, original[4].d, 'pants back')
H.equal(comps[6].d, original[6].d, 'shoes back')
reply = toggle('hat', false)
H.equal(props[0] and props[0].d, 5, 'hat back on for a look')
H.equal(stateOf(reply.toggles, 'hat'), false)
toggle('hat', true)
H.equal(props[0], nil, 'hat off again')
H.equal(#triggered, 0, 'switching sends nothing to the server')
H.equal(call('kora_clothing:nui:setClothingToggle', 'garbage').ok, false)
H.equal(toggle('gloves', true).ok, false, 'unknown switch refused')

-- Confirm never saves a removed item, and the ped gets everything back.
toggle('shirt', true); toggle('pants', true); toggle('shoes', true)
call('kora_clothing:nui:confirm', {})
local confirm = triggered[#triggered]
for _, id in ipairs({ 3, 4, 6, 8, 11 }) do
    H.equal(confirm.args[1].skin.components[tostring(id)].d, original[id].d, 'confirm snapshot carries the original ' .. id)
end
H.equal(confirm.args[1].skin.props['0'].d, 5, 'confirm snapshot carries the original hat')
close()
sameAs(original, 'after confirm')
H.equal(toggle('shirt', true).ok, false, 'no switches without a session')

-- Cancel / Esc.
original = open('barber')
toggle('shirt', true); toggle('shoes', true)
close(true)
sameAs(original, 'after cancel')

-- Death while items are off: the cache's isDead change ends the session.
original = open('barber')
toggle('shirt', true); toggle('pants', true)
H.equal(type(cacheHandlers.isDead), 'function', 'listens to the kora_lib cache death change')
dead = true
cacheHandlers.isDead(true, false)
dead = false
sameAs(original, 'after death')
H.equal(triggered[#triggered].name, 'kora_clothing:server:cancelSession')
close(true)

-- Resource stop while items are off.
original = open('hairdresser')
toggle('shirt', true); toggle('shoes', true)
for _, handler in ipairs(stopHandlers) do handler('kora_clothing') end
sameAs(original, 'after resource stop')
close(true)

-- Female models use the female bare values.
_G.GetEntityModel = function() return 'mp_f_freemode_01' end
original = open('hairdresser')
toggle('shirt', true); toggle('pants', true); toggle('shoes', true)
topIs(true, 'female shirt off')
H.equal(comps[4].d, 15, 'female pants off')
H.equal(comps[6].d, 35, 'female shoes off')
close()
sameAs(original, 'female after confirm')
_G.GetEntityModel = function() return 'mp_m_freemode_01' end

-- Wearing a saved outfit keeps the switches as they were; turning one back on
-- puts on the outfit's item, and cancel still returns to the opening look.
original = open('barber')
toggle('shirt', true)
outfitSkin = { components = {}, props = { ['0'] = { d = 9, t = 0 } } }
for id = 0, 11 do outfitSkin.components[tostring(id)] = { d = 60 + id, t = 1 } end
reply = call('kora_clothing:nui:loadOutfit', { id = 1 })
H.equal(reply.ok, true)
H.equal(stateOf(reply.clothingToggles, 'shirt'), true, 'shirt stays off on the new outfit')
H.equal(comps[11].d, 15)
H.equal(props[0], nil, 'the outfit hat is off too, like the switch says')
toggle('shirt', false)
H.equal(comps[11].d, 71, 'shirt back on is the outfit top')
toggle('hat', false)
H.equal(props[0] and props[0].d, 9, 'hat back on is the outfit hat')
close(true)
sameAs(original, 'cancel after an outfit')

-- Works with the tattoo undress feature switched off, using the stock bare values.
Config.tattoo.undress.enabled = false
original = open('barber')
toggle('shirt', true)
topIs(true, 'shirt off with tattoo undress off')
close(true)
sameAs(original, 'restored')
Config.tattoo.undress.enabled = true

-- Other menus get no switches unless listed in services.
for _, service in ipairs({ 'clothing', 'tattoo' }) do
    original = open(service)
    H.equal(openMessage().clothingToggles, nil, service .. ' has no switches')
    H.equal(toggle('shirt', true).ok, false)
    close(true)
end
cfg.services = { 'barber', 'hairdresser', 'clothing' }
original = open('clothing')
H.equal(ids(openMessage().clothingToggles), 'hat,shirt,pants,shoes', 'a listed clothing shop shows them')
H.equal(stateOf(openMessage().clothingToggles, 'hat'), false, 'a clothing shop leaves the hat on')
close(true)
cfg.services = { 'barber', 'hairdresser' }

-- Single switches off, the legacy shirt option, and the master switch.
cfg.items.pants = false
original = open('barber')
H.equal(ids(openMessage().clothingToggles), 'hat,shirt,shoes')
H.equal(toggle('pants', true).ok, false)
H.equal(comps[4].d, original[4].d)
close(true)
cfg.items.pants = true
Config.ui.barberTopToggle = false
open('barber')
H.equal(ids(openMessage().clothingToggles), 'hat,pants,shoes', 'barberTopToggle = false still hides the shirt')
close(true)
Config.ui.barberTopToggle = nil
cfg.enabled = false
open('barber')
H.equal(openMessage().clothingToggles, nil, 'no switches when disabled')
H.equal(toggle('shirt', true).ok, false)
topIs(false, 'top untouched when disabled')
close(true)
cfg.enabled = true

-- Opening while downed is refused with a message, not in silence.
messages, triggered, notices = {}, {}, {}
LocalPlayer.state.emsDown = 'laststand'
netEvents['qb-clothing:client:openMenu'](2)
H.equal(#triggered, 0, 'no request while downed')
H.equal(notices[#notices] and notices[#notices].type, 'error', 'the player is told why')
LocalPlayer.state.emsDown = false
netEvents['qb-clothing:client:openMenu'](2)
H.equal(triggered[#triggered].name, 'kora_clothing:server:requestSession')

-- A menu really on screen ignores a second open; one that lost its screen
-- (no NUI focus) is cleared and the request goes through.
original = open('barber')
toggle('shirt', true)
triggered = {}
netEvents['qb-clothing:client:openMenu'](2)
H.equal(#triggered, 0, 'an open menu is left alone')
nuiFocused = false
messages = {}
netEvents['qb-clothing:client:openMenu'](2)
H.equal(triggered[1] and triggered[1].name, 'kora_clothing:server:cancelSession', 'the stale session is dropped server-side')
H.equal(triggered[2] and triggered[2].name, 'kora_clothing:server:requestSession', 'and the new menu is requested')
H.equal(messages[#messages].action, 'kora_clothing:nui:close')
sameAs(original, 'stale session cleared')
nuiFocused = true

H.finish()

-- Tattoo studio undress buttons: preview only, and every way out of the menu
-- (confirm, cancel/Esc, death, resource stop) puts the original clothing back.
local H = dofile('test/harness.lua')

local netEvents, nuiCallbacks, stopHandlers, threads, messages, triggered = {}, {}, {}, {}, {}, {}
_G.RegisterNetEvent = function(name, fn) netEvents[name] = fn end
_G.AddEventHandler = function(name, fn) if name == 'onResourceStop' then stopHandlers[#stopHandlers + 1] = fn end end
_G.RegisterNUICallback = function(name, fn) nuiCallbacks[name] = fn end
_G.CreateThread = function(fn) threads[#threads + 1] = fn end
_G.GetCurrentResourceName = function() return 'kora_clothing' end
_G.exports = setmetatable({}, { __call = function() end, __index = function() return function() end end })
_G.PlayerId = function() return 1 end
_G.GetPlayerServerId = function() return 1 end
_G.LocalPlayer = { state = {} }
local bagHandlers = {}
_G.AddStateBagChangeHandler = function(filter, _, fn) bagHandlers[filter] = fn end
_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.PlayerPedId = function() return 1 end
_G.GetEntityModel = function() return 'mp_m_freemode_01' end
_G.joaat = function(value) return value end
_G.FreezeEntityPosition = function() end
_G.SetNuiFocus = function() end
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

_G.Kora = {
    notify = { send = function() end },
    events = { trigger = function(name, ...) triggered[#triggered + 1] = { name = name, args = { ... } }; return true end },
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

-- Defaults.
H.equal(Config.tattoo.undress.enabled, true)
H.equal(table.concat(Config.tattoo.undress.autoUndressOnOpen, ','), 'top,legs,headwear', 'opens as the studio always did: top, legs and head cover off')
H.equal(#Config.tattoo.undress.parts, 4)
H.equal(Config.tattooStrip.male[11].d, 15, 'the legacy strip no longer leaves a t-shirt on component 11')

-- Open: the default parts are bare, shoes stay on, the NUI gets the buttons.
local original = open()
H.equal(comps[11].d, 15, 'top bared (jacket/shirt)')
H.equal(comps[8].d, 15, 'undershirt bared')
H.equal(comps[3].d, 15, 'arms/gloves bared')
H.equal(comps[4].d, 21, 'male legs bared')
H.equal(comps[6].d, original[6].d, 'shoes stay on by default')
H.equal(props[0], nil, 'hat off')
H.equal(props[1], nil, 'glasses off')
H.equal(comps[1].d, 0, 'mask off')
local data = openMessage()
H.equal(#data.undress.parts, 4)
H.equal(table.concat(data.undress.active, ','), 'top,legs,headwear')
H.equal(data.undress.parts[1].id, 'top')

-- Toggles are local previews: dress/undress single parts, shoes, all.
local reply = call('kora_clothing:nui:setUndress', { part = 'top', undressed = false })
H.equal(reply.ok, true)
H.equal(comps[11].d, original[11].d, 'top back on')
H.equal(comps[8].t, original[8].t)
H.equal(table.concat(reply.active, ','), 'legs,headwear')
reply = call('kora_clothing:nui:setUndress', { part = 'shoes', undressed = true })
H.equal(comps[6].d, 34, 'male shoes bared')
reply = call('kora_clothing:nui:setUndress', { part = 'all', undressed = true })
H.equal(#reply.active, 4)
reply = call('kora_clothing:nui:setUndress', { part = 'all', undressed = false })
H.equal(#reply.active, 0)
sameAs(original, 'all dressed again')
H.equal(call('kora_clothing:nui:setUndress', { part = 'nonsense', undressed = true }).ok, false, 'unknown part refused')
H.equal(call('kora_clothing:nui:setUndress', 'garbage').ok, false)
H.equal(#triggered, 0, 'toggling sends nothing to the server')
-- Bared twice then dressed once still restores the real original, not a bare value.
call('kora_clothing:nui:setUndress', { part = 'top', undressed = true })
call('kora_clothing:nui:setUndress', { part = 'top', undressed = true })
call('kora_clothing:nui:setUndress', { part = 'top', undressed = false })
H.equal(comps[11].d, original[11].d, 'double undress keeps the first original')

-- Camera zone buttons keep working while parts are bared.
call('kora_clothing:nui:setUndress', { part = 'all', undressed = true })
H.equal(call('kora_clothing:nui:camera', { zone = 'torso' }).zone, 'torso', 'camera zone focus works while undressed')
H.equal(cameraZone, 'torso')
call('kora_clothing:nui:setUndress', { part = 'all', undressed = false })

-- Confirm never saves the bare look.
call('kora_clothing:nui:setUndress', { part = 'all', undressed = true })
call('kora_clothing:nui:confirm', {})
local confirm = triggered[#triggered]
H.equal(confirm.name, 'kora_clothing:server:confirmSession')
H.equal(confirm.args[1].skin.components['11'].d, original[11].d, 'confirm snapshot carries the original top')
H.equal(confirm.args[1].skin.components['4'].d, original[4].d, 'confirm snapshot carries the original legs')
H.equal(confirm.args[1].skin.props['0'].d, 5, 'confirm snapshot carries the original hat')
netEvents['kora_clothing:client:closeSession']({ ok = true })
sameAs(original, 'after confirm')
H.equal(call('kora_clothing:nui:setUndress', { part = 'top', undressed = true }).ok, false, 'no toggles without a session')

-- Cancel / Esc (both end as a cancelled close that re-applies the opening look).
original = open()
netEvents['kora_clothing:client:closeSession']({ ok = true, cancelled = true })
sameAs(original, 'after cancel')

-- Death: the preview clothing goes back and the session is cancelled.
original = open()
local watch = threads[#threads]
dead = true
watch()
dead = false
sameAs(original, 'after death')
H.equal(triggered[#triggered].name, 'kora_clothing:server:cancelSession', 'dying in the studio ends the session')

-- Last stand keeps the ped alive (IsEntityDead false): the emsDown state bag
-- value, via the watchdog or the state-bag listener, still cancels the session.
original = open()
watch = threads[#threads]
LocalPlayer.state.emsDown = 'laststand'
watch()
LocalPlayer.state.emsDown = false
sameAs(original, 'after last stand')
H.equal(triggered[#triggered].name, 'kora_clothing:server:cancelSession', 'last stand ends the session')

original = open()
local before = #triggered
H.equal(before, 0)
bagHandlers.emsDown('player:1', 'emsDown', 'laststand')
sameAs(original, 'after last stand bag change')
H.equal(#triggered, before + 1, 'state bag change cancels once')
bagHandlers.emsDown('player:1', 'emsDown', 'dead')
H.equal(#triggered, before + 1, 'a second down event does not cancel twice')
netEvents['kora_clothing:client:closeSession']({ ok = true, cancelled = true })

-- Opening while downed is refused and the server session handed back.
LocalPlayer.state.emsDown = 'dead'
messages, triggered = {}, {}
netEvents['kora_clothing:client:openSession']({ mode = 'shop', service = 'tattoo', model = 'mp_m_freemode_01', skin = {} })
H.equal(openMessage(), nil, 'no menu while downed')
H.equal(triggered[#triggered].name, 'kora_clothing:server:cancelSession', 'server session handed back')
LocalPlayer.state.emsDown = false

-- Resource stop while bared.
original = open()
H.equal(comps[11].d, 15)
for _, handler in ipairs(stopHandlers) do handler('kora_clothing') end
sameAs(original, 'after resource stop')

-- Another resource stopping changes nothing.
original = open()
for _, handler in ipairs(stopHandlers) do handler('some_other_resource') end
H.equal(comps[11].d, 15, 'unrelated resource stop leaves the session alone')
netEvents['kora_clothing:client:closeSession']({ ok = true, cancelled = true })

-- Female models use the female bare values.
_G.GetEntityModel = function() return 'mp_f_freemode_01' end
original = open()
H.equal(comps[4].d, 15, 'female legs bared')
call('kora_clothing:nui:setUndress', { part = 'shoes', undressed = true })
H.equal(comps[6].d, 35, 'female shoes bared')
netEvents['kora_clothing:client:closeSession']({ ok = true })
sameAs(original, 'female after confirm')
_G.GetEntityModel = function() return 'mp_m_freemode_01' end

-- Other services never get buttons or undress.
original = open('clothing')
sameAs(original, 'clothing shop untouched')
H.equal(openMessage().undress, nil, 'no buttons outside the tattoo studio')
H.equal(call('kora_clothing:nui:setUndress', { part = 'top', undressed = true }).ok, false)
netEvents['kora_clothing:client:closeSession']({ ok = true, cancelled = true })

-- Config off: the old fixed strip, no buttons, no toggle.
Config.tattoo.undress.enabled = false
original = open()
H.equal(openMessage().undress, nil, 'no buttons when disabled')
H.equal(comps[11].d, 15, 'the legacy strip still bares the top')
H.equal(comps[4].d, 21, 'the legacy strip still bares the legs')
H.equal(call('kora_clothing:nui:setUndress', { part = 'top', undressed = false }).ok, false, 'toggles refused when disabled')
netEvents['kora_clothing:client:closeSession']({ ok = true })
sameAs(original, 'legacy strip restored')

-- An out-of-range bare drawable is skipped rather than faulting the game.
Config.tattoo.undress.enabled = true
_G.GetNumberOfPedDrawableVariations = function(_, id) return id == 4 and 10 or 200 end
dress(); comps[4] = { d = 3, t = 2 }
original = open(tattoo, true)
H.equal(comps[4].d, original[4].d, 'legs left alone when the bare drawable does not exist')
H.equal(comps[11].d, 15)
netEvents['kora_clothing:client:closeSession']({ ok = true })

H.finish()

-- Barber / hairdresser shirt toggle: preview only, restored on every way out of the menu.
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
_G.AddStateBagChangeHandler = function() end
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
_G.QBTheme = { refresh = function() end }
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

_G.QB = {
    notify = { send = function() end },
    events = { trigger = function(name, ...) triggered[#triggered + 1] = { name = name, args = { ... } }; return true end },
}
_G.Kora = _G.QB

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
    netEvents['qbclothing:client:openSession']({ mode = 'shop', service = service or 'tattoo', model = GetEntityModel(), skin = skin, tattoos = {} })
    return original, skin
end
local function openMessage()
    for _, message in ipairs(messages) do if message.action == 'qbclothing:nui:open' then return message.data end end
end
local function call(name, data)
    local reply
    nuiCallbacks[name](data, function(value) reply = value end)
    return reply
end

local function topIs(expected, label)
    for _, id in ipairs({ 3, 8, 11 }) do
        H.equal(comps[id].d, expected and 15 or 30 + id, label .. ': component ' .. id)
    end
end

-- Menu text: locales/en.json supplies the defaults, kora_lib's Kora.lang a translation.
_G.LoadResourceFile = function() return '{}' end
_G.json = { decode = function() return { ui = { color = 'Color', none = 'None' } } end }
_G.Kora.lang = function(key) if key == 'ui.none' then return 'Ninguno' end return key end

-- Default on, for barbers and hairdressers only.
H.equal(Config.ui.barberTopToggle, true)
local original = open('barber')
local data = openMessage()
H.equal(data.topToggle.active, false, 'barber gets the shirt button, dressed')
H.equal(data.undress, nil, 'the tattoo toolbar is not sent to barbers')
topIs(false, 'dressed')
H.equal(data.strings.color, 'Color', 'English default reads Color')
H.equal(data.strings.none, 'Ninguno', 'a translation replaces the default')

-- Toggle off and on.
local reply = call('qbclothing:nui:setTop', { undressed = true })
H.equal(reply.ok, true)
H.equal(reply.active, true)
topIs(true, 'bared')
H.equal(comps[4].d, original[4].d, 'legs untouched')
H.equal(comps[2].d, original[2].d, 'hair untouched')
reply = call('qbclothing:nui:setTop', { undressed = false })
H.equal(reply.active, false)
topIs(false, 'put back')
call('qbclothing:nui:setTop', { undressed = true })
call('qbclothing:nui:setTop', { undressed = true })
call('qbclothing:nui:setTop', { undressed = false })
topIs(false, 'bared twice then dressed once keeps the real original')
H.equal(#triggered, 0, 'toggling sends nothing to the server')
H.equal(call('qbclothing:nui:setTop', 'garbage').ok, false)

-- Confirm never saves the bare top, and the ped gets it back.
call('qbclothing:nui:setTop', { undressed = true })
call('qbclothing:nui:confirm', {})
local confirm = triggered[#triggered]
for _, id in ipairs({ 3, 8, 11 }) do
    H.equal(confirm.args[1].skin.components[tostring(id)].d, original[id].d, 'confirm snapshot carries the original ' .. id)
end
netEvents['qbclothing:client:closeSession']({ ok = true })
sameAs(original, 'after confirm')
H.equal(call('qbclothing:nui:setTop', { undressed = true }).ok, false, 'no toggle without a session')

-- Cancel / Esc.
original = open('barber')
call('qbclothing:nui:setTop', { undressed = true })
netEvents['qbclothing:client:closeSession']({ ok = true, cancelled = true })
sameAs(original, 'after cancel')

-- Death while bared.
original = open('barber')
call('qbclothing:nui:setTop', { undressed = true })
local watch = threads[#threads]
dead = true
watch()
dead = false
sameAs(original, 'after death')
H.equal(triggered[#triggered].name, 'qbclothing:server:cancelSession')

-- Resource stop while bared.
original = open('hairdresser')
call('qbclothing:nui:setTop', { undressed = true })
for _, handler in ipairs(stopHandlers) do handler('kora_clothing') end
sameAs(original, 'after resource stop')

-- Female models use the same bare components.
_G.GetEntityModel = function() return 'mp_f_freemode_01' end
original = open('hairdresser')
call('qbclothing:nui:setTop', { undressed = true })
topIs(true, 'female bared')
netEvents['qbclothing:client:closeSession']({ ok = true })
sameAs(original, 'female after confirm')
_G.GetEntityModel = function() return 'mp_m_freemode_01' end

-- Works with the tattoo undress feature switched off, using the stock bare values.
Config.tattoo.undress.enabled = false
original = open('barber')
call('qbclothing:nui:setTop', { undressed = true })
topIs(true, 'bared with tattoo undress off')
netEvents['qbclothing:client:closeSession']({ ok = true, cancelled = true })
sameAs(original, 'restored')
Config.tattoo.undress.enabled = true

-- Other services never get the button or the callback.
for _, service in ipairs({ 'clothing', 'tattoo' }) do
    original = open(service)
    H.equal(openMessage().topToggle, nil, service .. ' has no shirt button')
    H.equal(call('qbclothing:nui:setTop', { undressed = true }).ok, false)
    netEvents['qbclothing:client:closeSession']({ ok = true, cancelled = true })
end

-- Config off: no button, callback refused, nothing bared.
Config.ui.barberTopToggle = false
original = open('barber')
H.equal(openMessage().topToggle, nil, 'no button when disabled')
H.equal(call('qbclothing:nui:setTop', { undressed = true }).ok, false)
topIs(false, 'top untouched when disabled')
netEvents['qbclothing:client:closeSession']({ ok = true, cancelled = true })
Config.ui.barberTopToggle = true

H.finish()

-- Config.rotatePointerLock defaults on and is sent with the NUI open payload.
local H = dofile('test/harness.lua')

local handlers = {}
_G.RegisterNetEvent = function(name, fn) handlers[name] = fn end
_G.AddEventHandler = function() end
_G.RegisterNUICallback = function() end
_G.CreateThread = function() end
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
_G.SendNUIMessage = function() end
_G.Camera = { start = function() end, stop = function() end }
_G.QBTheme = { refresh = function() end }
_G.Kora = { notify = { send = function() end } }
for _, name in ipairs({ 'GetNumberOfPedDrawableVariations', 'GetNumberOfPedTextureVariations', 'GetNumberOfPedPropDrawableVariations', 'GetNumberOfPedPropTextureVariations' }) do
    _G[name] = function() return 0 end
end
_G.GetPedDrawableVariation = function() return 0 end
_G.GetPedTextureVariation = function() return 0 end
_G.GetPedPropIndex = function() return -1 end
_G.GetPedPropTextureIndex = function() return 0 end
_G.SetPedHairColor = function() end
_G.GetNumHairColors = function() return 64 end
_G.GetPedHairRgbColor = function() return 0, 0, 0 end
_G.ClearPedProp = function() end
_G.SetPedComponentVariation = function() end
_G.SetPedPropIndex = function() end
_G.ClearPedDecorations = function() end
_G.DisableAllControlActions = function() end
_G.EnableControlAction = function() end
_G.Wait = function() end

_G.IsRadarHidden = function() return false end
_G.DisplayRadar = function() end
_G.GetResourceState = function() return 'stopped' end
local sent
_G.SendNUIMessage = function(message) if message.action == 'qbclothing:nui:open' then sent = message.data end end

dofile('config.lua')
dofile('shared/components.lua')
_G.RegisterCommand = _G.RegisterCommand or function() end
_G.TriggerEvent = _G.TriggerEvent or function() end
dofile('client/client.lua')

local function open()
    sent = nil
    handlers['qbclothing:client:openSession']({ mode = 'shop', service = 'clothing', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
    handlers['qbclothing:client:closeSession']({ ok = true })
    return sent
end

H.equal(Config.rotatePointerLock, true, 'on by default')
H.equal(open().rotatePointerLock, true, 'sent on by default')

Config.rotatePointerLock = false
H.equal(open().rotatePointerLock, false, 'read live on the next open')

H.finish()

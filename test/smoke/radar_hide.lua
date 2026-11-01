-- The radar fallback: when kora_hud is not running, an open clothing menu hides
-- the minimap and a close restores it. Gated by Config.hideRadarInMenu.
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

local radarVisible, displayCalls = true, {}
_G.IsRadarHidden = function() return not radarVisible end
_G.DisplayRadar = function(visible) radarVisible = visible; displayCalls[#displayCalls + 1] = visible end
local hudState = 'stopped'
_G.GetResourceState = function() return hudState end

dofile('config.lua')
dofile('shared/components.lua')
_G.RegisterCommand = _G.RegisterCommand or function() end
_G.TriggerEvent = _G.TriggerEvent or function() end
dofile('client/client.lua')

local function cycle(service)
    handlers['qbclothing:client:openSession']({ mode = 'shop', service = service, model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
    local during = radarVisible
    handlers['qbclothing:client:closeSession']({ ok = true })
    return during, radarVisible
end

H.equal(Config.hideRadarInMenu, true, 'on by default')

-- Every kind of menu goes through the same session path.
for _, service in ipairs({ 'clothing', 'barber', 'tattoo', 'creation' }) do
    radarVisible, displayCalls = true, {}
    local during, after = cycle(service)
    H.equal(during, false, service .. ' hides the radar while open')
    H.equal(after, true, service .. ' restores the radar on close')
end

-- Cancel (not ok) restores too.
radarVisible = true
handlers['qbclothing:client:openSession']({ mode = 'shop', service = 'clothing', model = 'mp_m_freemode_01', skin = {} })
handlers['qbclothing:client:closeSession']({ ok = false, cancelled = true })
H.equal(radarVisible, true, 'cancel restores the radar')

-- A radar that was already hidden stays hidden.
radarVisible, displayCalls = false, {}
cycle('clothing')
H.equal(#displayCalls, 0, 'an already hidden radar is left alone')
H.equal(radarVisible, false)

-- kora_hud running: it owns the radar, so the fallback does nothing.
hudState, radarVisible, displayCalls = 'started', true, {}
cycle('clothing')
H.equal(#displayCalls, 0, 'no fallback while kora_hud is started')

-- Config off.
hudState, radarVisible, displayCalls = 'stopped', true, {}
Config.hideRadarInMenu = false
local during = cycle('clothing')
H.equal(during, true, 'false leaves the radar alone')
H.equal(#displayCalls, 0)

H.finish()

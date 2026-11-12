-- Config.rotateDragGuard defaults on, is sent with the open payload, and the
-- rotateEnd NUI callback settles the orbit where it is.
local H = dofile('test/harness.lua')

local handlers = {}
_G.RegisterNetEvent = function(name, fn) handlers[name] = fn end
_G.AddEventHandler = function() end
local callbacks = {}
_G.RegisterNUICallback = function(name, fn) callbacks[name] = fn end
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
local ended = 0
_G.Camera = { start = function() end, stop = function() end, rotateEnd = function() ended = ended + 1 end }
_G.KoraTheme = { refresh = function() end }
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
_G.SendNUIMessage = function(message) if message.action == 'kora_clothing:nui:open' then sent = message.data end end

dofile('config.lua')
dofile('shared/components.lua')
_G.RegisterCommand = _G.RegisterCommand or function() end
_G.TriggerEvent = _G.TriggerEvent or function() end
_G.IsEntityDead = _G.IsEntityDead or function() return false end
_G.PlayerPedId = _G.PlayerPedId or function() return 1 end
dofile('client/client.lua')

local function open()
    sent = nil
    handlers['kora_clothing:client:openSession']({ mode = 'shop', service = 'clothing', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
    handlers['kora_clothing:client:closeSession']({ ok = true })
    return sent
end

H.equal(Config.rotateDragGuard, true, 'on by default')
H.equal(open().rotateDragGuard, true, 'sent on by default')

Config.rotateDragGuard = false
H.equal(open().rotateDragGuard, false, 'read live on the next open')

H.equal(Config.ui.showControlsHint, true, 'controls hint is on by default')
H.equal(open().showControlsHint, true, 'hint option is sent on by default')
Config.ui.showControlsHint = false
H.equal(open().showControlsHint, false, 'hint option is read live on the next open')
Config.ui.showControlsHint = true
H.equal(Config.ui.creatorOpensOnHair, true, 'creator opens on hair by default')
H.equal(open().creatorOpensOnHair, true, 'creator-start option is sent on by default')
Config.ui.creatorOpensOnHair = false
H.equal(open().creatorOpensOnHair, false, 'creator-start option is read live on the next open')
Config.ui.creatorOpensOnHair = true

local replied
callbacks['kora_clothing:nui:rotateEnd']({}, function(value) replied = value end)
H.equal(ended, 1, 'rotateEnd callback settles the camera')
H.ok(type(replied) == 'table', 'rotateEnd callback replies')

-- Config.rotateRestoreCursor (default on): the cursor hidden for a plain drag goes
-- back where the drag began. A visible cursor is never moved.
local cursorAt
_G.SetCursorLocation = function(x, y) cursorAt = { x, y } end
local function release(origin) callbacks['kora_clothing:nui:rotateEnd'](origin, function() end) end
release({ x = 0.25, y = 0.75 })
H.equal(cursorAt, nil, 'no menu open, no move')
handlers['kora_clothing:client:openSession']({ mode = 'shop', service = 'clothing', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
release({ x = 0.25, y = 0.75 })
H.ok(cursorAt and cursorAt[1] == 0.25 and cursorAt[2] == 0.75, 'the hidden cursor goes back where the drag began')
cursorAt = nil
release({})
H.equal(cursorAt, nil, 'no origin, no move')
release({ x = 4, y = -1 })
H.ok(cursorAt and cursorAt[1] == 1.0 and cursorAt[2] == 0.0, 'an origin off screen is clamped')
cursorAt = nil
Config.rotateRestoreCursor = false
release({ x = 0.25, y = 0.75 })
H.equal(cursorAt, nil, 'rotateRestoreCursor off leaves the cursor where it is')
Config.rotateRestoreCursor = true
Config.rotateHideCursor = false
release({ x = 0.25, y = 0.75 })
H.equal(cursorAt, nil, 'a cursor left visible for a plain drag is never moved')
Config.rotateHideCursor = true
handlers['kora_clothing:client:closeSession']({ ok = true })

-- Camera side: the orbit stops at the live angle, not at the old goal.
_G.Kora.util = { clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end }
Config.testMode = true
local realCamera = _G.Camera
_G.Camera = nil
dofile('client/camera.lua')
local runtime = Camera._testRuntime
runtime.setAngles(100.0, 140.0)
Camera.rotateEnd()
H.equal(runtime.targetAngle(), 100.0, 'rotateEnd drops the pending target angle')

H.finish()

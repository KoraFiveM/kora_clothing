-- Config.rotateMode: controls-mode drags (client/rotate.lua) start, rotate from the look
-- control, stop on release / cancel / safety timeout / close, and always give NUI
-- focus and the cursor back; the NUI callbacks and the open payload follow the mode.
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
_G.QBTheme = { refresh = function() end }
_G.Kora = { notify = { send = function() end } }
_G.QB = _G.Kora -- the committed client code still says QB; the rename is in flight
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
dofile('client/client.lua')

dofile('client/rotate.lua')

local function open()
    sent = nil
    handlers['qbclothing:client:openSession']({ mode = 'shop', service = 'clothing', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
    return sent
end

local clock, frame = 0, 0
local focus = {}          -- every SetNuiFocus call, in order
local cursor              -- last SetCursorLocation
local rotated, rotateEnds, messages = {}, 0, {}
local held, look, cancelKey = false, 0.0, false
local onFrame = function() end
local threads = {}

_G.GetGameTimer = function() return clock end
_G.SetNuiFocus = function(a, b) focus[#focus + 1] = { a, b } end
local keepInput = false
_G.SetNuiFocusKeepInput = function(v) keepInput = v end
_G.SetCursorLocation = function(x, y) cursor = { x, y } end
_G.GetDisabledControlNormal = function(_, control) if control == 1 then return look end return 0.0 end
_G.GetControlNormal = function() return 0.0 end
_G.IsDisabledControlPressed = function() return held end
_G.IsControlPressed = function() return false end
_G.IsDisabledControlJustPressed = function() return cancelKey end
_G.IsControlJustPressed = function() return false end
_G.CreateThread = function(fn) threads[#threads + 1] = fn end
_G.Wait = function() clock = clock + 16; frame = frame + 1; onFrame(frame) end
_G.SendNUIMessage = function(message)
    if message.action == 'qbclothing:nui:open' then sent = message.data end
    messages[#messages + 1] = message
end
_G.Camera = {
    start = function() end, stop = function() end,
    rotate = function(deg) rotated[#rotated + 1] = deg end,
    rotateEnd = function() rotateEnds = rotateEnds + 1 end,
}

local function reset()
    clock, frame, focus, cursor = 0, 0, {}, nil
    rotated, rotateEnds, messages = {}, 0, {}
    held, look, cancelKey = false, 0.0, false
    onFrame = function() end
    threads = {}
    RotateControl.stop('close')
end
local function lastFocus() local f = focus[#focus]; return f and f[1], f and f[2] end
local function runThread() local fn = table.remove(threads, 1); fn() end
local function lastMessage() return messages[#messages] end

H.equal(Config.rotateMode, 'pointer', 'pointer lock is the default mode')
H.equal(Config.rotateSensitivity, 1.0, 'rotate sensitivity defaults to 1')
H.equal(Config.rotateRightButton, true, 'right button rotates by default')
H.equal(RotateControl.mode(), 'pointer', 'mode resolves to pointer')
Config.rotateMode = 'nonsense'
H.equal(RotateControl.mode(), 'pointer', 'unknown mode falls back to pointer')
Config.rotateMode = 'pointer'
H.equal(RotateControl.mode(), 'pointer', 'pointer mode')
Config.rotatePointerLock = false
H.equal(RotateControl.mode(), 'plain', 'rotatePointerLock = false still turns pointer capture off')
Config.rotatePointerLock = true
Config.rotateMode = 'controls'

H.equal(open().rotateMode, 'controls', 'payload carries the mode')
H.equal(sent.rotateSensitivity, 1.0, 'payload carries the rotate sensitivity')
H.equal(sent.rotateInvert, false, 'payload carries the invert option')
H.ok(sent.rotateRecenterEdge < 0.1, 'payload carries a small recenter edge')
H.equal(sent.rotateRightButton, true, 'payload carries the right-button option')
Config.rotateMode = 'recenter'
H.equal(open().rotateMode, 'recenter', 'mode is read live on the next open')
Config.rotateMode = 'controls'
handlers['qbclothing:client:closeSession']({ ok = true })

reset()
Config.rotateMode = 'plain'
H.equal(RotateControl.start(0, 0.4, 0.6), false, 'not started outside controls mode')
Config.rotateMode = 'controls'
Config.rotateRightButton = false
H.equal(RotateControl.start(2, 0.4, 0.6), false, 'right button refused when disabled')
Config.rotateRightButton = true
H.equal(RotateControl.start(1, 0.4, 0.6), false, 'unknown button refused')
H.equal(#focus, 0, 'a refused start never touches NUI focus')

reset()
H.equal(RotateControl.start(0, 0.25, 0.75), true, 'drag starts')
H.equal(RotateControl.start(0, 0.5, 0.5), false, 'a second start while running is refused')
local a, b = lastFocus()
H.equal(a, true, 'focus kept'); H.equal(b, false, 'cursor hidden for the drag')
H.equal(keepInput, true, 'game receives the mouse during the drag')
held, look = true, 0.5
onFrame = function(n) if n == 5 then held, look = false, 0.0 end end
runThread()
H.equal(#rotated, 5, 'rotated once per frame the mouse moved')
H.equal(rotated[1], -4.0, 'moving right turns by -delta * sensitivity (8 deg/unit)')
H.equal(RotateControl.isActive(), false, 'drag over after release')
a, b = lastFocus()
H.equal(a, true, 'focus restored'); H.equal(b, true, 'cursor restored')
H.equal(keepInput, false, 'input handed back to the NUI')
H.equal(cursor[1], 0.25, 'cursor put back where it was (x)'); H.equal(cursor[2], 0.75, 'cursor put back where it was (y)')
H.ok(rotateEnds >= 1, 'camera settled')
H.equal(lastMessage().action, 'qbclothing:nui:rotateStopped', 'NUI told the drag ended')
H.equal(lastMessage().data.reason, 'released', 'reason is release')

reset()
Config.rotateInvert = true
RotateControl.start(0, 0.5, 0.5)
held, look = true, 0.5
onFrame = function(n) if n == 2 then held = false end end
runThread()
H.equal(rotated[1], 4.0, 'rotateInvert reverses the direction')
Config.rotateInvert = false

reset()
Config.rotateControlsSensitivity = 2.0
RotateControl.start(0, 0.5, 0.5)
held, look = true, 1.0
onFrame = function(n) if n == 2 then held = false end end
runThread()
H.equal(rotated[1], -2.0, 'sensitivity read live')
Config.rotateControlsSensitivity = 8.0

reset()
RotateControl.start(0, 0.5, 0.5)
held = false
runThread()
H.ok(clock >= 400 and clock < 600, 'unseen button ends after the grace period')
H.equal(lastFocus(), true, 'focus restored after the grace stop')
H.equal(select(2, lastFocus()), true, 'cursor restored after the grace stop')

-- button never reported by the game: a moving mouse keeps the drag alive, an idle one ends it
reset()
RotateControl.start(0, 0.5, 0.5)
held, look = false, 0.5
onFrame = function(n) if n == 80 then look = 0.0 end end
runThread()
H.ok(#rotated >= 79, 'drag outlives the press grace while the mouse keeps moving')
H.ok(clock > 1600 and clock < 1800, 'ends shortly after the mouse stops')
H.equal(lastMessage().data.reason, 'released', 'idle end reports released')

reset()
RotateControl.start(0, 0.5, 0.5)
held = true
onFrame = function(n) if n == 3 then cancelKey = true end end
runThread()
H.equal(RotateControl.isActive(), false, 'cancel key ends the drag')
H.equal(lastMessage().data.reason, 'cancelled', 'reason is cancelled')
H.equal(select(2, lastFocus()), true, 'focus restored after cancel')

reset()
Config.rotateControlsMaxSeconds = 1.0
RotateControl.start(0, 0.5, 0.5)
held = true
runThread()
H.equal(RotateControl.isActive(), false, 'safety stop ends a drag whose release was never seen')
H.equal(lastMessage().data.reason, 'timeout', 'reason is timeout')
H.ok(clock >= 1000 and clock < 1100, 'stopped at the limit')
H.equal(select(2, lastFocus()), true, 'focus restored after the safety stop')
H.equal(keepInput, false, 'keep-input cleared after the safety stop')
Config.rotateControlsMaxSeconds = 30.0

reset()
H.equal(RotateControl.start(2, 0.5, 0.5), true, 'right button starts a drag')
RotateControl.stop('nui')

reset()
local reply
callbacks['qbclothing:nui:rotateStart']({ button = 0, x = 0.3, y = 0.3 }, function(v) reply = v end)
H.equal(reply.active, false, 'no session, no drag')
open()
callbacks['qbclothing:nui:rotateStart']({ button = 0, x = 0.3, y = 0.3 }, function(v) reply = v end)
H.equal(reply.active, true, 'session open: Lua takes the drag')
H.equal(RotateControl.isActive(), true, 'drag running')
callbacks['qbclothing:nui:rotateEnd']({}, function() end)
H.equal(RotateControl.isActive(), false, 'rotateEnd stops the controls drag')
H.equal(select(2, lastFocus()), true, 'rotateEnd restores focus')

-- menu closes mid-drag: no stuck drag, focus is fully dropped, not re-enabled
callbacks['qbclothing:nui:rotateStart']({ button = 0, x = 0.3, y = 0.3 }, function(v) reply = v end)
H.equal(RotateControl.isActive(), true, 'drag running before close')
handlers['qbclothing:client:closeSession']({ ok = true })
H.equal(RotateControl.isActive(), false, 'closing the menu ends the drag')
local a2, b2 = lastFocus()
H.equal(a2, false, 'focus dropped on close'); H.equal(b2, false, 'cursor dropped on close')
H.equal(keepInput, false, 'keep-input cleared on close')

-- recenter callback: only in recenter mode, with a session, throttled
reset()
open()
callbacks['qbclothing:nui:recenter']({}, function(v) reply = v end)
H.equal(reply.moved, false, 'recenter ignored outside recenter mode')
Config.rotateMode = 'recenter'
callbacks['qbclothing:nui:recenter']({}, function(v) reply = v end)
H.equal(reply.moved, true, 'recenter moves the cursor')
H.equal(cursor[1], 0.5, 'to the centre'); H.equal(cursor[2], 0.5, 'to the centre')
callbacks['qbclothing:nui:recenter']({}, function(v) reply = v end)
H.equal(reply.moved, false, 'throttled when repeated at once')
clock = clock + 100
callbacks['qbclothing:nui:recenter']({}, function(v) reply = v end)
H.equal(reply.moved, true, 'allowed again after the interval')
Config.rotateMode = 'controls'

H.finish()

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
_G.RegisterCommand = _G.RegisterCommand or function() end
_G.TriggerEvent = _G.TriggerEvent or function() end
_G.IsEntityDead = _G.IsEntityDead or function() return false end
_G.PlayerPedId = _G.PlayerPedId or function() return 1 end
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

H.equal(Config.rotateMode, 'plain', 'plain (no cursor moves) is the default mode')
H.equal(Config.rotateSensitivity, 1.0, 'rotate sensitivity defaults to 1')
H.equal(Config.rotateRightButton, true, 'right button rotates by default')
H.equal(RotateControl.mode(), 'plain', 'mode resolves to plain')
Config.rotateMode = 'nonsense'
H.equal(RotateControl.mode(), 'plain', 'unknown mode falls back to plain')
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
H.equal(#threads, 0, 'a plain drag runs no Lua thread')
H.equal(#focus, 0, 'a plain drag never touches NUI focus')
H.equal(cursor, nil, 'a plain drag never moves the cursor')
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

-- Capture mode: Lua reads the cursor every frame, turns by its travel and pulls it
-- back to the centre itself, so a fast drag can never carry it to an edge or out
-- of the window. NUI focus is never touched.
reset()
Config.rotateMode = 'capture'
local nuiCursor = { 480, 810 }   -- where the button went down (0.25, 0.75 of 1920x1080)
local pendingPull, pulls, furthest = false, 0, 0
_G.GetActiveScreenResolution = function() return 1920, 1080 end
_G.GetNuiCursorPosition = function() return nuiCursor[1], nuiCursor[2] end
_G.SetCursorLocation = function(x, y)
    cursor = { x, y }
    if x == 0.5 and y == 0.5 then pendingPull, pulls = true, pulls + 1 end
end
local hand = 40 -- pixels per frame: 2400 px/s at 60 fps, more than a screen width a second
local function fastDrag(stopAt)
    onFrame = function(n)
        if pendingPull then nuiCursor, pendingPull = { 960, 540 }, false end -- the pull lands next frame
        nuiCursor[1] = nuiCursor[1] + hand
        furthest = math.max(furthest, math.abs(nuiCursor[1] - 960))
        if n == stopAt then RotateControl.stop('nui') end
    end
end
H.equal(RotateControl.start(0, 0.25, 0.75), true, 'capture drag starts')
H.equal(#focus, 0, 'capture never touches NUI focus')
H.equal(keepInput, false, 'the game does not get the mouse')
H.equal(pulls, 1, 'the cursor is pulled to the centre at once')
fastDrag(60)
runThread()
H.equal(RotateControl.isActive(), false, 'released')
H.equal(#rotated, 59, 'turned every frame after the first pull landed')
local total = 0
for _, deg in ipairs(rotated) do total = total + deg end
H.ok(math.abs(total - (-59 * hand * 0.15)) < 1e-6, 'every pixel the hand moved turned the camera, the pull jumps did not')
H.ok(furthest < 1920 * 0.08 + hand + 1, 'the cursor never got further than one pull distance from the centre')
H.ok(pulls > 10, 'pulled back again and again during the drag')
H.equal(#focus, 0, 'still no focus change')
H.equal(cursor[1], 0.25, 'cursor put back where the drag began (x)'); H.equal(cursor[2], 0.75, 'cursor put back where the drag began (y)')
H.ok(rotateEnds >= 1, 'camera settled')

-- Leftward, inverted and with sensitivity: same pull, opposite turn.
reset()
nuiCursor, pendingPull, pulls, furthest = { 960, 540 }, false, 0, 0
hand = -25
Config.rotateInvert, Config.rotateSensitivity = true, 2.0
RotateControl.start(0, 0.5, 0.5)
fastDrag(30)
runThread()
H.equal(rotated[1], -25 * 0.15 * 2.0, 'invert and sensitivity apply')
H.ok(furthest < 1920 * 0.08 + 26, 'held near the centre going left too')
Config.rotateInvert, Config.rotateSensitivity = false, 1.0
hand = 40

-- The safety limit ends a drag whose release was never seen, and tells the NUI.
reset()
nuiCursor, pendingPull = { 960, 540 }, false
Config.rotateControlsMaxSeconds = 1.0
RotateControl.start(0, 0.5, 0.5)
onFrame = function() if pendingPull then pendingPull = false end end
runThread()
H.equal(RotateControl.isActive(), false, 'safety stop')
H.equal(lastMessage().data.reason, 'timeout')
Config.rotateControlsMaxSeconds = 30.0

-- Through the NUI callbacks, with a session; a menu closing mid-drag ends it.
reset()
open()
callbacks['qbclothing:nui:rotateStart']({ button = 0, x = 0.4, y = 0.4 }, function(v) reply = v end)
H.equal(reply.active, true, 'session open: Lua takes the capture drag')
callbacks['qbclothing:nui:rotateEnd']({}, function() end)
H.equal(RotateControl.isActive(), false, 'rotateEnd stops it')
H.equal(cursor[1], 0.4, 'cursor back where it began')
callbacks['qbclothing:nui:rotateStart']({ button = 0, x = 0.4, y = 0.4 }, function(v) reply = v end)
handlers['qbclothing:client:closeSession']({ ok = true })
H.equal(RotateControl.isActive(), false, 'closing the menu ends the capture drag')
H.equal(open().rotateMode, 'capture', 'payload carries capture')
Config.rotateMode = 'plain'
H.equal(open().rotateMode, 'plain', 'payload carries plain')
Config.rotateMode = 'capture'
handlers['qbclothing:client:closeSession']({ ok = true })

-- Plain (the default): the callbacks never start a Lua drag or move the cursor; the
-- NUI's batched rotate messages are the whole drag.
reset()
Config.rotateMode = 'plain'
open()
local threadsBefore, focusBefore = #threads, #focus -- the session's own, not the drag's
callbacks['qbclothing:nui:rotateStart']({ button = 0, x = 0.4, y = 0.4 }, function(v) reply = v end)
H.equal(reply.active, false, 'plain: Lua declines the drag')
callbacks['qbclothing:nui:recenter']({}, function(v) reply = v end)
H.equal(reply.moved, false, 'plain: the cursor is never recentred')
H.equal(cursor, nil, 'plain: SetCursorLocation never called')
H.equal(#threads, threadsBefore, 'plain: no per-frame thread')
H.equal(#focus, focusBefore, 'plain: NUI focus untouched during the drag')
callbacks['qbclothing:nui:rotate']({ deltaDeg = 3.0 }, function() end)
H.equal(#rotated, 1, 'plain: the NUI delta turns the camera')
handlers['qbclothing:client:closeSession']({ ok = true })
Config.rotateMode = 'capture'

-- Without the cursor natives capture declines, and the NUI falls back to recentring.
reset()
local savedRead = _G.GetNuiCursorPosition
_G.GetNuiCursorPosition = nil
H.equal(RotateControl.start(0, 0.5, 0.5), false, 'declined without GetNuiCursorPosition')
_G.GetNuiCursorPosition = savedRead
open()
clock = clock + 1000 -- past the recentre throttle left by the recenter tests above
callbacks['qbclothing:nui:recenter']({}, function(v) reply = v end)
H.equal(reply.moved, true, 'the recenter fallback is allowed in capture mode')
handlers['qbclothing:client:closeSession']({ ok = true })
Config.rotateMode = 'controls'

-- Per-menu modes (Config.rotateModeByService): barbers and hairdressers capture so the
-- cursor cannot leave the window; character creation and the other menus keep
-- Config.rotateMode ('plain'), whose untouched cursor fixed the creation flicker.
reset()
Config.rotateMode = 'plain'
H.equal(Config.rotateModeByService.barber, 'capture', 'barbers default to capture')
H.equal(Config.rotateModeByService.hairdresser, 'capture', 'hairdressers default to capture')
H.equal(Config.rotateModeByService.creation, nil, 'creation has no override by default')
H.equal(Config.rotateModeByService.clothing, nil, 'clothing shops have no override by default')
H.equal(Config.rotateModeByService.tattoo, nil, 'tattoo studios have no override by default')
H.equal(RotateControl.mode('creation'), 'plain', 'creation resolves plain')
H.equal(RotateControl.mode('barber'), 'capture', 'barber resolves capture')
H.equal(RotateControl.mode('hairdresser'), 'capture', 'hairdresser resolves capture')
H.equal(RotateControl.mode('clothing'), 'plain', 'clothing resolves plain')
H.equal(RotateControl.mode('tattoo'), 'plain', 'tattoo resolves plain')
H.equal(RotateControl.mode(), 'plain', 'no menu: Config.rotateMode')
Config.rotateModeByService.barber = 'nonsense'
H.equal(RotateControl.mode('barber'), 'plain', 'an unknown override falls back to Config.rotateMode')
Config.rotateModeByService.barber = 'capture'
Config.rotateMode = 'recenter'
H.equal(RotateControl.mode('creation'), 'recenter', 'an unset menu follows Config.rotateMode')
Config.rotateMode = 'plain'

local function openAs(mode, service, model)
    sent = nil
    handlers['qbclothing:client:openSession']({ mode = mode, service = service, model = model or 'mp_m_freemode_01', skin = {}, tattoos = {} })
    return sent
end
local function press() callbacks['qbclothing:nui:rotateStart']({ button = 0, x = 0.4, y = 0.4 }, function(v) reply = v end) end
local function release() callbacks['qbclothing:nui:rotateEnd']({}, function() end) end
local function close() handlers['qbclothing:client:closeSession']({ ok = true }) end
local function runLast() local fn = table.remove(threads); fn() end

-- Character creation (new character and admin) stays plain: a press runs no thread,
-- never moves the cursor and never touches NUI focus.
for _, mode in ipairs({ 'firstCharacter', 'admin' }) do
    reset()
    H.equal(openAs(mode, 'creation').rotateMode, 'plain', mode .. ' creation opens in plain')
    local threadsBefore, focusBefore = #threads, #focus
    press()
    H.equal(reply.active, false, mode .. ' creation: Lua declines the drag')
    callbacks['qbclothing:nui:recenter']({}, function(v) reply = v end)
    H.equal(reply.moved, false, mode .. ' creation: the cursor is never recentred')
    H.equal(#threads, threadsBefore, mode .. ' creation: no drag thread')
    H.equal(#focus, focusBefore, mode .. ' creation: NUI focus untouched')
    H.equal(cursor, nil, mode .. ' creation: SetCursorLocation never called')
    H.equal(RotateControl.isActive(), false, mode .. ' creation: no Lua drag')
    close()
end
for _, service in ipairs({ 'clothing', 'tattoo' }) do
    reset()
    H.equal(openAs('shop', service).rotateMode, 'plain', service .. ' opens in plain')
    close()
end

-- Barber: capture, but nothing runs until the button goes down; the thread starts on
-- the press and ends on the very frame the button comes up.
reset()
nuiCursor, pendingPull, pulls = { 960, 540 }, false, 0
H.equal(openAs('shop', 'barber').rotateMode, 'capture', 'the barber opens in capture')
H.equal(RotateControl.isActive(), false, 'barber open: no drag yet')
H.equal(pulls, 0, 'barber open: the cursor is not moved before a press')
local threadsBefore, focusBefore = #threads, #focus
press()
H.equal(reply.active, true, 'barber: Lua takes the drag on the press')
H.equal(#threads, threadsBefore + 1, 'barber: exactly one drag thread, started by the press')
H.equal(pulls, 1, 'barber: the cursor is pulled to the centre on the press')
H.equal(#focus, focusBefore, 'barber: capture never touches NUI focus')
local releasedAt
fastDrag(-1)
local drive = onFrame
onFrame = function(n) drive(n); if n == 12 then releasedAt = n; release() end end
runLast()
H.equal(RotateControl.isActive(), false, 'barber: released')
H.equal(frame, releasedAt, 'barber: the thread stops on the frame the button comes up')
H.ok(#rotated > 0, 'barber: the drag turned the camera')
H.equal(cursor[1], 0.4, 'barber: cursor back where the drag began')
local pullsAfter = pulls
onFrame = function() end
H.equal(#threads, threadsBefore, 'barber: no thread left after release')
H.equal(pulls, pullsAfter, 'barber: no pull after release')

-- Closing the barber mid-drag stops the thread at once, without a final pull.
reset()
nuiCursor, pendingPull, pulls = { 960, 540 }, false, 0
openAs('shop', 'barber')
press()
H.equal(RotateControl.isActive(), true, 'barber: drag running before close')
fastDrag(-1)
drive = onFrame
local closedAt
onFrame = function(n) drive(n); if n == 7 then closedAt = n; close() end end
runLast()
H.equal(RotateControl.isActive(), false, 'barber: closing the menu ends the drag')
H.equal(frame, closedAt, 'barber: the thread stops on the frame the menu closes')
pullsAfter = pulls
press()
H.equal(reply.active, false, 'barber closed: a late press starts nothing')
H.equal(pulls, pullsAfter, 'barber closed: no pull after close')

-- A close before the thread's first frame also leaves nothing running.
reset()
openAs('shop', 'barber')
press()
local dragThread = threads[#threads]
close()
dragThread()
H.equal(frame, 0, 'barber: a drag closed before its first frame never runs')

-- The hairdresser (female characters at the same shops) captures too; the mode
-- follows the service, so the stub's model does not matter here.
reset()
H.equal(openAs('shop', 'hairdresser').rotateMode, 'capture', 'the hairdresser opens in capture')
close()

H.finish()

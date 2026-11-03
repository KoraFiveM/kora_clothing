-- Drag-to-rotate input that does not depend on the cursor staying on screen.
--
-- Config.rotateMode, or the menu's own Config.rotateModeByService entry when set
-- (none set by default: every menu follows Config.rotateMode, 'plain'):
--   'plain'    (default) a normal press/move/release drag in the NUI. Nothing happens
--              here: no thread, no cursor move, no focus change. The NUI turns the
--              camera from its own mouse movement (one message per frame), so the
--              cursor it draws is never disturbed.
--   'capture'  the NUI keeps its focus and cursor, so it always sees the
--              button come up, and hands the drag to this file. Every frame the
--              cursor is read (GetNuiCursorPosition), the camera turns by how far
--              it moved, and once it strays a little from the screen centre it is
--              pulled back (SetCursorLocation). The pull happens here, the same
--              frame, not after a round trip from the NUI, so even a fast flick
--              cannot carry the cursor to a screen edge or out of the window. The
--              cursor is hidden while dragging and put back where the drag began.
--              FiveM's NUI refuses browser pointer lock, which is why 'pointer'
--              always ended up recentring from the NUI and could be outrun.
--   'controls'  the NUI hands the drag to this file. NUI focus drops
--              its cursor and passes input to the game (SetNuiFocusKeepInput +
--              SetNuiFocus(true, false)); without the keep-input flag the game
--              gets no mouse at all and every read would be zero. Mouse movement
--              reaches the game as INPUT_LOOK_LR and is read here every frame.
--              The cursor is hidden and never moves, so it cannot leave the
--              window and nothing is ever recentred. The drag
--              ends when the mouse button is released, on a cancel key, after
--              Config.rotateControlsMaxSeconds, or when the session closes, and
--              NUI focus + the cursor position are put back.
--   'recenter' the NUI keeps the normal cursor drag and asks for the cursor to
--              be put back at the screen centre when it nears an edge.
--   'pointer'  the browser Pointer Lock request (Config.rotatePointerLock); the NUI
--              turns the camera from movementX and never toggles NUI focus. FiveM's
--              NUI refuses the lock, so in practice it falls back to recenter.

RotateControl = {}

local LOOK_LR = 1
local BUTTON_CONTROL = { [0] = 24, [2] = 25 } -- left = INPUT_ATTACK, right = INPUT_AIM
local CANCEL_CONTROLS = { 177, 200, 202 }      -- backspace, pause/esc, cancel
-- The held button may not be visible to the game until the first frame after the
-- focus switch; give it this long before an unseen button counts as released.
local PRESS_GRACE_MS = 400
local RECENTER_MIN_INTERVAL_MS = 40

local MODES = { capture = true, controls = true, recenter = true, pointer = true, plain = true }

-- 'capture' mode. Degrees per pixel match the NUI's DRAG_ROTATION_DEG_PER_PIXEL
-- (scaled by Config.rotateSensitivity), so a drag turns the same in every mode.
local CAPTURE_DEG_PER_PIXEL = 0.15
local CAPTURE_PULL = 0.08          -- pull the cursor back once it is this far (fraction of the screen) from the centre
local CAPTURE_RETRY_FRAMES = 8     -- a pull still not seen after this many frames is sent again

local active -- the running drag: { mode, control, startedAt, seen, movedAt, x, y, ... }

---The mode in effect for a menu. `service` is the session's service ('clothing',
---'barber', 'hairdresser', 'tattoo', 'creation'): its Config.rotateModeByService
---entry wins when set, otherwise Config.rotateMode applies. An unknown value falls
---back to the default ('plain'); the older Config.rotatePointerLock = false still
---turns plain 'pointer' capture off.
---@param service string|nil
---@return string
function RotateControl.mode(service)
    local overrides = Config.rotateModeByService
    local mode = service ~= nil and type(overrides) == 'table' and overrides[service] or nil
    if not MODES[mode] then mode = Config.rotateMode end
    if not MODES[mode] then mode = 'plain' end
    if mode == 'pointer' and Config.rotatePointerLock == false then return 'plain' end
    return mode
end

function RotateControl.isActive()
    return active ~= nil
end

---@param name string
---@param fallback number
local function number(name, fallback)
    local value = tonumber(Config[name])
    if not value or value ~= value then return fallback end
    return value
end

local function lookDelta()
    local value = GetDisabledControlNormal(0, LOOK_LR)
    -- The control lock leaves LOOK_LR enabled, and a disabled read can report 0
    -- for an enabled control; take whichever one saw the mouse move.
    if value == 0 then value = GetControlNormal(0, LOOK_LR) end
    return value
end

-- The held button can be reported on any input group once NUI focus drops its cursor,
-- and as either a pressed flag or a non-zero normal; accept all of them.
local function buttonHeld(control)
    for group = 0, 2 do
        if IsDisabledControlPressed(group, control) or IsControlPressed(group, control) then return true end
    end
    return GetDisabledControlNormal(0, control) > 0.5 or GetControlNormal(0, control) > 0.5
end

local function cancelPressed()
    for _, control in ipairs(CANCEL_CONTROLS) do
        if IsDisabledControlJustPressed(0, control) or IsControlJustPressed(0, control) then return true end
    end
    return false
end

---Ends the drag. Safe to call when none is running. `reason` 'close' (menu or
---resource going away) leaves NUI focus alone because the caller is about to
---drop it; any other reason hands focus and the cursor back as they were.
---@param reason string
---@return boolean wasActive
function RotateControl.stop(reason)
    local drag = active
    if not drag then return false end
    active = nil
    if Camera and Camera.rotateEnd then Camera.rotateEnd() end
    if drag.mode == 'capture' then
        -- NUI focus never changed; only the cursor goes back where the drag began.
        if reason ~= 'close' then
            SetCursorLocation(drag.x, drag.y)
            SendNUIMessage({ action = 'qbclothing:nui:rotateStopped', data = { reason = reason } })
            -- A centre pull still in flight lands after the line above and would leave
            -- the cursor in the middle of the screen; put it back once more next frame.
            CreateThread(function()
                Wait(0)
                if not active then SetCursorLocation(drag.x, drag.y) end
            end)
        end
        return true
    end
    -- Input goes back to the NUI whatever the reason, so a closing menu never
    -- leaves the game receiving the mouse through a dead focus.
    SetNuiFocusKeepInput(false)
    if reason ~= 'close' then
        SetNuiFocus(true, true)
        SetCursorLocation(drag.x, drag.y)
        SendNUIMessage({ action = 'qbclothing:nui:rotateStopped', data = { reason = reason } })
    end
    return true
end

---One frame of a capture drag: returns the cursor's horizontal travel in pixels
---since the last frame and pulls the cursor back to the centre once it strays.
---A pull lands a frame or so later as a jump to the centre; that jump is not the
---player's hand, so only what moved after it counts.
---@param drag table the running capture drag
---@param x number cursor position (GetNuiCursorPosition, game pixels)
---@param y number
---@param width number game resolution (GetActiveScreenResolution)
---@param height number
---@return number dx
function RotateControl.captureStep(drag, x, y, width, height)
    local cx, cy = width * 0.5, height * 0.5
    local dx = 0
    if drag.pulling then
        if math.abs(x - cx) <= width * CAPTURE_PULL * 0.5 and math.abs(y - cy) <= height * CAPTURE_PULL * 0.5 then
            dx = x - cx
            drag.pulling = false
        else
            if drag.lastX then dx = x - drag.lastX end
            drag.pullFrames = drag.pullFrames + 1
            if drag.pullFrames > CAPTURE_RETRY_FRAMES then drag.pulling = false end
        end
    elseif drag.lastX then
        dx = x - drag.lastX
    end
    drag.lastX, drag.lastY = x, y
    if not drag.pulling and (math.abs(x - cx) > width * CAPTURE_PULL or math.abs(y - cy) > height * CAPTURE_PULL) then
        SetCursorLocation(0.5, 0.5)
        drag.pulling, drag.pullFrames = true, 0
    end
    return dx
end

local function captureAvailable()
    return type(GetNuiCursorPosition) == 'function' and type(SetCursorLocation) == 'function'
        and type(GetActiveScreenResolution) == 'function'
end

local function runCapture(drag)
    CreateThread(function()
        local width, height = GetActiveScreenResolution()
        width, height = math.max(1, tonumber(width) or 1920), math.max(1, tonumber(height) or 1080)
        local maxMs = number('rotateControlsMaxSeconds', 30.0) * 1000.0
        local direction = Config.rotateInvert == true and -1.0 or 1.0
        local degPerPixel = CAPTURE_DEG_PER_PIXEL * math.max(0.1, number('rotateSensitivity', 1.0)) * direction
        while active == drag do
            local x, y = GetNuiCursorPosition()
            local dx = RotateControl.captureStep(drag, tonumber(x) or 0, tonumber(y) or 0, width, height)
            -- Same direction as the cursor drag: moving right turns the view clockwise.
            if dx ~= 0 and Camera then Camera.rotate(-dx * degPerPixel) end
            if GetGameTimer() - drag.startedAt > maxMs then
                RotateControl.stop('timeout')
                break
            end
            Wait(0)
        end
    end)
end

---Starts a Lua-owned drag ('capture' or 'controls' mode). Returns false (the NUI
---then keeps its own drag) in any other mode, when a drag is already running,
---the button is unknown, or capture's natives are missing.
---@param button number 0 = left, 2 = right
---@param x number cursor position as a 0..1 fraction of the screen, put back afterwards
---@param y number
---@param service string|nil the open menu's service, for its rotate mode
---@return boolean
function RotateControl.start(button, x, y, service)
    local mode = RotateControl.mode(service)
    if active or (mode ~= 'controls' and mode ~= 'capture') then return false end
    local control = BUTTON_CONTROL[tonumber(button) or 0]
    if not control then return false end
    if control == 25 and Config.rotateRightButton == false then return false end

    x, y = tonumber(x) or 0.5, tonumber(y) or 0.5
    if mode == 'capture' then
        if not captureAvailable() then return false end
        local drag = {
            mode = 'capture',
            startedAt = GetGameTimer(),
            x = math.max(0.0, math.min(1.0, x)),
            y = math.max(0.0, math.min(1.0, y)),
            -- The cursor starts where the button went down: pull it to the centre first.
            pulling = true,
            pullFrames = 0,
        }
        active = drag
        SetCursorLocation(0.5, 0.5)
        runCapture(drag)
        return true
    end
    local drag = {
        mode = 'controls',
        control = control,
        startedAt = GetGameTimer(),
        seen = false,
        movedAt = nil,
        x = math.max(0.0, math.min(1.0, x)),
        y = math.max(0.0, math.min(1.0, y)),
    }
    active = drag
    SetNuiFocusKeepInput(true)
    SetNuiFocus(true, false)

    CreateThread(function()
        local maxMs = number('rotateControlsMaxSeconds', 30.0) * 1000.0
        while active == drag do
            local now = GetGameTimer()
            local delta = lookDelta()
            if delta ~= 0 then drag.movedAt = now end
            if delta ~= 0 and Camera then
                -- Same direction as the cursor drag: moving right turns the view clockwise.
                local direction = Config.rotateInvert == true and -1.0 or 1.0
                Camera.rotate(-delta * number('rotateControlsSensitivity', 8.0) * direction)
            end

            if buttonHeld(drag.control) then
                drag.seen = true
            elseif drag.seen then
                RotateControl.stop('released')
                break
            elseif now - drag.startedAt > PRESS_GRACE_MS
                and now - (drag.movedAt or drag.startedAt) > number('rotateControlsIdleSeconds', 0.4) * 1000.0 then
                -- The game never reported the button (it was pressed before NUI handed
                -- the mouse over). While the mouse keeps moving the drag is assumed to
                -- be held, so it no longer dies after the first fraction of a second.
                RotateControl.stop('released')
                break
            end

            if cancelPressed() then
                RotateControl.stop('cancelled')
                break
            end
            if now - drag.startedAt > maxMs then
                RotateControl.stop('timeout')
                break
            end
            Wait(0)
        end
    end)
    return true
end

local lastRecenter = -RECENTER_MIN_INTERVAL_MS
---Puts the cursor at the screen centre ('recenter' mode, and the NUI's fallback
---when 'pointer' or 'capture' could not start), throttled.
---@param service string|nil the open menu's service, for its rotate mode
---@return boolean moved
function RotateControl.recenter(service)
    local mode = RotateControl.mode(service)
    if mode ~= 'recenter' and mode ~= 'pointer' and mode ~= 'capture' then return false end
    local now = GetGameTimer()
    if now - lastRecenter < RECENTER_MIN_INTERVAL_MS then return false end
    lastRecenter = now
    SetCursorLocation(0.5, 0.5)
    return true
end

-- Drag-to-rotate input that does not depend on the cursor staying on screen.
--
-- Config.rotateMode:
--   'controls' (default) the NUI hands the drag to this file. NUI focus drops
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
--   'pointer'  the browser Pointer Lock request (Config.rotatePointerLock).
--   'plain'    a normal press/move/release drag, no capture.

RotateControl = {}

local LOOK_LR = 1
local BUTTON_CONTROL = { [0] = 24, [2] = 25 } -- left = INPUT_ATTACK, right = INPUT_AIM
local CANCEL_CONTROLS = { 177, 200, 202 }      -- backspace, pause/esc, cancel
-- The held button may not be visible to the game until the first frame after the
-- focus switch; give it this long before an unseen button counts as released.
local PRESS_GRACE_MS = 400
local RECENTER_MIN_INTERVAL_MS = 40

local MODES = { controls = true, recenter = true, pointer = true, plain = true }

local active -- the running drag: { control, startedAt, seen, x, y }

---The mode in effect. An unknown value falls back to the default; the older
---Config.rotatePointerLock = false still turns plain 'pointer' capture off.
---@return string
function RotateControl.mode()
    local mode = Config.rotateMode
    if not MODES[mode] then mode = 'controls' end
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

local function buttonHeld(control)
    return IsDisabledControlPressed(0, control) or IsControlPressed(0, control)
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

---Starts a controls-mode drag. Returns false (the NUI then keeps its own drag)
---when the mode is not 'controls', a drag is already running, or the button is unknown.
---@param button number 0 = left, 2 = right
---@param x number cursor position as a 0..1 fraction of the screen, put back afterwards
---@param y number
---@return boolean
function RotateControl.start(button, x, y)
    if RotateControl.mode() ~= 'controls' or active then return false end
    local control = BUTTON_CONTROL[tonumber(button) or 0]
    if not control then return false end
    if control == 25 and Config.rotateRightButton == false then return false end

    x, y = tonumber(x) or 0.5, tonumber(y) or 0.5
    local drag = {
        control = control,
        startedAt = GetGameTimer(),
        seen = false,
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
            if delta ~= 0 and Camera then
                -- Same direction as the cursor drag: moving right turns the view clockwise.
                local direction = Config.rotateInvert == true and -1.0 or 1.0
                Camera.rotate(-delta * number('rotateControlsSensitivity', 8.0) * direction)
            end

            if buttonHeld(drag.control) then
                drag.seen = true
            elseif drag.seen or now - drag.startedAt > PRESS_GRACE_MS then
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
---Puts the cursor at the screen centre ('recenter' mode), throttled.
---@return boolean moved
function RotateControl.recenter()
    if RotateControl.mode() ~= 'recenter' then return false end
    local now = GetGameTimer()
    if now - lastRecenter < RECENTER_MIN_INTERVAL_MS then return false end
    lastRecenter = now
    SetCursorLocation(0.5, 0.5)
    return true
end

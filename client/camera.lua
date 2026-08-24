-- Illenium-style orbiting fitting-room camera: smooth zoom between body-region
-- presets (Config.camera.zones) and a continuous horizontal orbit driven by
-- NUI drag input, instead of a jump-cut between fixed angles.

Camera = {}

local cam
local active = false
local pedRef

local state = { radius = 2.2, height = 0.3, fov = 45.0, angle = 0.0 }
local target = { zone = 'full', angle = 0.0 }

local function lerp(current, goal, rate)
    return current + (goal - current) * rate
end

function Camera.start(ped)
    if cam then Camera.stop() end
    pedRef = ped
    active = true

    local first = Config.camera.zones.full
    state.radius, state.height, state.fov, state.angle = first.camOffset.y, first.boneOffset.z + first.camOffset.z, first.fov, 0.0
    target.zone, target.angle = 'full', 0.0

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 300, true, true)

    CreateThread(function()
        local last = GetGameTimer()
        while active and cam do
            local now = GetGameTimer()
            local dt = math.max(0.0, (now - last) / 1000.0)
            last = now

            local zoneCfg = Config.camera.zones[target.zone] or Config.camera.zones.full
            local zoomRate = math.min(1.0, dt * (1000.0 / math.max(50, Config.camera.transitionMs)))
            state.radius = lerp(state.radius, zoneCfg.camOffset.y, zoomRate)
            state.height = lerp(state.height, zoneCfg.boneOffset.z + zoneCfg.camOffset.z, zoomRate)
            state.fov = lerp(state.fov, zoneCfg.fov, zoomRate)
            state.angle = lerp(state.angle, target.angle, math.min(1.0, dt * 6.0))

            if pedRef and DoesEntityExist(pedRef) then
                local pedCoords = GetEntityCoords(pedRef)
                local heading = GetEntityHeading(pedRef)
                local targetHeight = pedCoords.z + zoneCfg.boneOffset.z
                local rad = math.rad(heading + state.angle)
                local camX = pedCoords.x - math.sin(rad) * state.radius
                local camY = pedCoords.y - math.cos(rad) * state.radius
                local camZ = pedCoords.z + state.height

                SetCamCoord(cam, camX, camY, camZ)
                PointCamAtCoord(cam, pedCoords.x, pedCoords.y, targetHeight)
                SetCamFov(cam, state.fov)
            end

            Wait(0)
        end
    end)
end

---@param zone string one of Config.camera.zones' keys
function Camera.setZone(zone)
    if not Config.camera.zones[zone] then return end
    target.zone = zone
end

---@param deltaDeg number added to the current orbit angle (positive = clockwise)
function Camera.rotate(deltaDeg)
    target.angle = (target.angle + (tonumber(deltaDeg) or 0.0)) % 360.0
end

function Camera.stop()
    active = false
    if cam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    pedRef = nil
end

function Camera.isActive()
    return active
end

-- Illenium-style orbiting fitting-room camera: smooth zoom between body-region
-- presets (Config.camera.zones), continuous free zoom on the mouse wheel, and a
-- continuous horizontal orbit driven by NUI drag input, instead of a jump-cut
-- between fixed angles.

Camera = {}

local cam
local active = false
local pedRef

local state = { radius = 2.2, height = 0.3, fov = 45.0, angle = 0.0 }
local target = { zone = 'full', angle = 0.0, zoomOffset = 0.0 }

-- What the occlusion resolve below decided: an orbit angle to swing around an
-- obstruction, a lift to clear a low one, and a fraction of the goal radius to
-- pull in to when the fan found no clear angle at all. Applied on top of the
-- live orbit every frame rather than baked into a fixed camera point, so the
-- player can still drag-rotate and zoom without the resolve going stale.
local occlusion = { angle = 0.0, lift = 0.0, radiusScale = 1.0 }
local occlusionDirty = false

local function lerp(current, goal, rate)
    return current + (goal - current) * rate
end

-- Angles wrap at 360 degrees. Interpolating the raw values makes a small
-- movement across that seam take the long way around (for example, 359° to
-- 1° would sweep backwards through 358°). Keep the live angle normalized so
-- every orbit transition follows the shortest arc.
local function lerpAngle(current, goal, rate)
    local delta = (goal - current + 540.0) % 360.0 - 180.0
    return (current + delta * rate) % 360.0
end

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

-- The selected zone's preset radius plus whatever the wheel has added, clamped
-- to the configured absolute bounds. Deliberately returned as the LERP GOAL
-- rather than written onto the live camera: the zone transition is already a
-- lerp towards this value, so a wheel notch part-way through a transition just
-- moves the target the lerp is chasing instead of fighting it for ownership of
-- state.radius (which is what writing the radius directly would do -- the next
-- frame's lerp would immediately drag it back towards the zone preset).
local function goalRadius(zoneCfg)
    local bounds = Config.camera.zoom
    return clamp(zoneCfg.camOffset.y + target.zoomOffset, bounds.min, bounds.max)
end

-- Ported from qbmultichar's scene.lua, which solves this exact problem for its
-- authored character cameras: without it a wall, a parked car or a passing ped
-- can sit between the camera and the ped being dressed. A capsule rather than a
-- zero-width ray so the camera does not end up grazing a wall, column or
-- foliage edge; the fan tries the same distance at other angles before anything
-- pulls the camera in, because swinging around a counter keeps the authored
-- framing while pulling in loses it.
local CAMERA_TRACE_FLAGS = 273 -- world geometry, objects, and vegetation
local CAMERA_TRACE_RADIUS = 0.28
local CAMERA_FAN_ANGLES = { 0.0, 28.0, -28.0, 55.0, -55.0, 82.0, -82.0, 180.0 }
local MID_SPINE_BONE = 24816 -- SKEL_Spine2

-- Camera-zone offsets are authored from the middle of the torso. Entity
-- coordinates, however, are at the ped's model origin (near the feet), which
-- shifts every close-up and puts the shoes frame below the model. Resolve the
-- anchor from the same spine bone the presets describe. The entity-coordinate
-- fallback keeps the camera usable for a model with an incomplete skeleton.
local function cameraAnchor(ped)
    local anchor = GetPedBoneCoords(ped, MID_SPINE_BONE, 0.0, 0.0, 0.0)
    if anchor and anchor.x and anchor.y and anchor.z then return anchor end
    return GetEntityCoords(ped)
end

local function traceCameraPath(subject, candidate)
    local handle = StartShapeTestCapsule(
        subject.x, subject.y, subject.z,
        candidate.x, candidate.y, candidate.z,
        CAMERA_TRACE_RADIUS, CAMERA_TRACE_FLAGS, pedRef or 0, 7
    )
    if not handle or handle == 0 then return nil end

    local deadline = GetGameTimer() + 250
    repeat
        local status, hit, impact = GetShapeTestResult(handle)
        if status == 2 then return hit == true or hit == 1, impact end
        if status == 0 then return nil end
        Wait(0)
    until GetGameTimer() >= deadline
    return nil
end

local function candidatePoint(pedCoords, heading, radius, height, angle, lift)
    local rad = math.rad(heading + angle)
    return vector3(
        pedCoords.x - math.sin(rad) * radius,
        pedCoords.y - math.cos(rad) * radius,
        pedCoords.z + height + lift
    )
end

local function resolveOcclusion()
    if not (pedRef and DoesEntityExist(pedRef)) then return end

    local zoneCfg = Config.camera.zones[target.zone] or Config.camera.zones.full
    local pedCoords = cameraAnchor(pedRef)
    local heading = GetEntityHeading(pedRef)
    local radius = goalRadius(zoneCfg)
    local height = zoneCfg.boneOffset.z + zoneCfg.camOffset.z

    -- Traced from the point the camera is actually aimed at, not the ped's
    -- feet: a waist-high shop counter is not between a face-framed camera and
    -- the ped's head, and tracing from floor level would insist that it is.
    local subject = vector3(pedCoords.x, pedCoords.y, pedCoords.z + zoneCfg.boneOffset.z)

    local firstImpact
    for index, angle in ipairs(CAMERA_FAN_ANGLES) do
        local lift = index > 5 and 0.65 or 0.0
        local candidate = candidatePoint(pedCoords, heading, radius, height, target.angle + angle, lift)
        local blocked, impact = traceCameraPath(subject, candidate)
        if blocked == false then
            occlusion.angle, occlusion.lift, occlusion.radiusScale = angle, lift, 1.0
            return
        end
        if blocked and not firstImpact then firstImpact = impact end
    end

    if firstImpact then
        local dx, dy, dz = firstImpact.x - subject.x, firstImpact.y - subject.y, firstImpact.z - subject.z
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        -- Last resort, and only when there is usable room in front of the
        -- obstruction: sit just short of it rather than inside it. Never closer
        -- than the free-zoom floor, which is already the distance below which
        -- the camera renders the inside of the ped's own head.
        if distance > 0.6 then
            occlusion.angle, occlusion.lift = 0.0, 0.0
            occlusion.radiusScale = clamp((distance - 0.25) / radius, Config.camera.zoom.min / radius, 1.0)
            return
        end
    end

    -- Either the obstruction is flush against the ped (nothing to pull in to)
    -- or every trace timed out, which a capsule test legitimately does while
    -- collision around a just-teleported ped is still streaming in. Keep the
    -- authored framing instead of snapping somewhere arbitrary -- the resolve
    -- re-runs on the next zone or zoom change regardless.
    occlusion.angle, occlusion.lift, occlusion.radiusScale = 0.0, 0.0, 1.0
end

function Camera.start(ped)
    if cam then Camera.stop() end
    pedRef = ped
    active = true

    local first = Config.camera.zones.full
    state.radius, state.height, state.fov, state.angle = first.camOffset.y, first.boneOffset.z + first.camOffset.z, first.fov, 0.0
    target.zone, target.angle, target.zoomOffset = 'full', 0.0, 0.0
    occlusion.angle, occlusion.lift, occlusion.radiusScale = 0.0, 0.0, 1.0
    occlusionDirty = false

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 300, true, true)

    -- Occlusion resolves on its own thread: traceCameraPath has to Wait for the
    -- shape test to report, and doing that inline would stall the very frame
    -- the camera is being positioned on. Coalesced through occlusionDirty so a
    -- wheel spin producing a dozen notches costs one fan, not a dozen.
    CreateThread(function()
        resolveOcclusion()
        while active and cam do
            if occlusionDirty then
                occlusionDirty = false
                resolveOcclusion()
            end
            Wait(120)
        end
    end)

    CreateThread(function()
        local last = GetGameTimer()
        while active and cam do
            local now = GetGameTimer()
            local dt = math.max(0.0, (now - last) / 1000.0)
            last = now

            local zoneCfg = Config.camera.zones[target.zone] or Config.camera.zones.full
            local zoomRate = math.min(1.0, dt * (1000.0 / math.max(50, Config.camera.transitionMs)))
            state.radius = lerp(state.radius, goalRadius(zoneCfg), zoomRate)
            state.height = lerp(state.height, zoneCfg.boneOffset.z + zoneCfg.camOffset.z, zoomRate)
            state.fov = lerp(state.fov, zoneCfg.fov, zoomRate)
            state.angle = lerpAngle(state.angle, target.angle, math.min(1.0, dt * 6.0))

            if pedRef and DoesEntityExist(pedRef) then
                local pedCoords = cameraAnchor(pedRef)
                local heading = GetEntityHeading(pedRef)
                local targetHeight = pedCoords.z + zoneCfg.boneOffset.z
                local camPoint = candidatePoint(
                    pedCoords, heading,
                    state.radius * occlusion.radiusScale, state.height,
                    state.angle + occlusion.angle, occlusion.lift
                )

                SetCamCoord(cam, camPoint.x, camPoint.y, camPoint.z)
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
    -- A preset is a jump-TO, not a nudge: it has to land on its own authored
    -- framing, so it discards whatever the wheel had accumulated. Without this
    -- a player who had zoomed right in would press "Full body" and still be
    -- looking at a close-up.
    target.zoomOffset = 0.0
    occlusionDirty = true
end

---@param deltaDeg number added to the current orbit angle (positive = clockwise)
function Camera.rotate(deltaDeg)
    target.angle = (target.angle + (tonumber(deltaDeg) or 0.0)) % 360.0
end

---@param delta number wheel notches; negative pulls the camera towards the ped
function Camera.zoom(delta)
    delta = tonumber(delta)
    if not delta or delta ~= delta then return end

    local bounds = Config.camera.zoom
    local zoneCfg = Config.camera.zones[target.zone] or Config.camera.zones.full

    -- Clamped against the CURRENT zone's own radius, so the offset can never
    -- describe a radius the goal clamp would reject. Clamping only the
    -- resulting radius (and letting the offset run free) would let the offset
    -- keep accumulating while the wheel spins, and the first notch back the
    -- other way would then do nothing at all -- the camera sits at the bound
    -- while several metres of dead travel unwind first, which reads as the
    -- wheel having stopped working.
    target.zoomOffset = clamp(
        target.zoomOffset + delta * bounds.step,
        bounds.min - zoneCfg.camOffset.y,
        bounds.max - zoneCfg.camOffset.y
    )
    occlusionDirty = true
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

-- Deliberately absent in production. Same convention as client.lua's
-- QBClothing._testRuntime: lets the standalone smoke suite exercise the zoom
-- clamp arithmetic without a running client.
if Config.testMode then
    Camera._testRuntime = {
        goalRadius = goalRadius,
        lerpAngle = lerpAngle,
        zoomOffset = function() return target.zoomOffset end,
        setZoomOffset = function(value) target.zoomOffset = value end,
    }
end

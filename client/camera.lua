-- Illenium-style orbiting fitting-room camera: smooth zoom between body-region
-- presets (Config.camera.zones), continuous free zoom on the mouse wheel, and a
-- continuous horizontal orbit driven by NUI drag input, instead of a jump-cut
-- between fixed angles.

Camera = {}

local cam
local active = false
local pedRef

local state = { radius = 2.2, height = 0.3, fov = 45.0, angle = 0.0, look = 0.0 }
local target = { zone = 'full', angle = 0.0, zoomOffset = 0.0 }

-- What the occlusion resolve below decided: an orbit angle to swing around an
-- obstruction, a lift to clear a low one, and a fraction of the goal radius to
-- pull in to when the fan found no clear angle at all. Applied on top of the
-- live orbit every frame rather than baked into a fixed camera point, so the
-- player can still drag-rotate and zoom without the resolve going stale.
local occlusion = { angle = 0.0, lift = 0.0, radiusScale = 1.0 }
local occlusionDirty = false

-- The occlusion result as it is applied: eased towards `occlusion` like every
-- other camera value, so a re-resolve never moves the camera in a single frame.
local applied = { angle = 0.0, lift = 0.0, radiusScale = 1.0 }

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

local clamp = Kora.util.clamp

-- Fraction of the remaining distance to cover this frame so a change is ~95%
-- done after Config.camera.transitionMs, at any frame rate.
local function settleRate(dt)
    local seconds = math.max(0.05, (tonumber(Config.camera.transitionMs) or 500) / 1000.0)
    return 1.0 - math.exp(-dt * 3.0 / seconds)
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

-- Ported from kora_multichar's scene.lua, which solves this exact problem for its
-- authored character cameras: without it a wall, a parked car or a passing ped
-- can sit between the camera and the ped being dressed. A capsule rather than a
-- zero-width ray so the camera does not end up grazing a wall, column or
-- foliage edge; the fan tries the same distance at other angles before anything
-- pulls the camera in, because swinging around a counter keeps the authored
-- framing while pulling in loses it.
local CAMERA_TRACE_FLAGS = 273 -- world geometry, objects, and vegetation
local CAMERA_TRACE_RADIUS = 0.28
local CAMERA_FAN_ANGLES = { 0.0, 28.0, -28.0, 55.0, -55.0, 82.0, -82.0, 180.0 }
local MID_SPINE_BONE = 24816 -- SKEL_Spine1

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

-- Vertical limits of the ped relative to the camera anchor. With
-- Config.camera.frameToBones (default) they come from the ped's own head and
-- foot bones, so they are right for any model or height; the model bounding box
-- is only the fallback (it is unreliable for freemode peds and used to cap the
-- face view at the shoulders and drop the shoes view below the floor).
--   low/high : bottom/top of the ped         head/feet : bone heights (bone mode)
--   ground   : the floor under the feet      margin    : look-at headroom below `high`
-- All are metres relative to the anchor. The defaults only apply where no
-- measurement is possible.
local HEAD_BONE = 31086      -- SKEL_Head
local L_FOOT_BONE = 14201    -- SKEL_L_Foot
local R_FOOT_BONE = 52301    -- SKEL_R_Foot
local HEAD_TOP = 0.12        -- skull top above the head bone
local FOOT_SOLE = 0.1        -- floor below the foot bones

-- The face centre sits about this far below the top of the head (box fallback).
local HEAD_MARGIN = 0.15

local pedBounds = { low = -1.3, high = 0.65, ground = -1.3, margin = HEAD_MARGIN }

local function validBone(c)
    return c and c.x and c.y and c.z
end

-- Bone-derived bounds, or nil when the skeleton readings are not plausible (a
-- ped that has not finished streaming reports zero vectors).
local function boneBounds(anchorZ, headZ, leftFootZ, rightFootZ)
    if not (headZ and leftFootZ and rightFootZ) then return nil end
    local footZ = math.min(leftFootZ, rightFootZ)
    if headZ - footZ < 0.5 then return nil end
    return {
        low = footZ - FOOT_SOLE - anchorZ,
        ground = footZ - FOOT_SOLE - anchorZ,
        high = headZ + HEAD_TOP - anchorZ,
        head = headZ - anchorZ,
        -- The shoes view is centred on the midpoint of both feet (the floor stays
        -- under the lower one) so a stepped pose does not tilt the framing.
        feet = (leftFootZ + rightFootZ) * 0.5 - anchorZ,
        margin = 0.0,
    }
end

local function applyBounds(bounds)
    pedBounds.low, pedBounds.high, pedBounds.ground = bounds.low, bounds.high, bounds.ground
    pedBounds.head, pedBounds.feet, pedBounds.margin = bounds.head, bounds.feet, bounds.margin
end

local function measurePedBounds(ped)
    local anchor = cameraAnchor(ped)

    if Config.camera.frameToBones ~= false and type(GetPedBoneCoords) == 'function' then
        local head = GetPedBoneCoords(ped, HEAD_BONE, 0.0, 0.0, 0.0)
        local left = GetPedBoneCoords(ped, L_FOOT_BONE, 0.0, 0.0, 0.0)
        local right = GetPedBoneCoords(ped, R_FOOT_BONE, 0.0, 0.0, 0.0)
        if validBone(head) and validBone(left) and validBone(right) then
            local bounds = boneBounds(anchor.z, head.z, left.z, right.z)
            if bounds then
                applyBounds(bounds)
                return true
            end
        end
    end

    pedBounds.head, pedBounds.feet, pedBounds.margin = nil, nil, HEAD_MARGIN
    if type(GetModelDimensions) ~= 'function' then return false end
    local minimum, maximum = GetModelDimensions(GetEntityModel(ped))
    if not minimum or not maximum then return false end

    local root = GetEntityCoords(ped)
    pedBounds.low = root.z + minimum.z - anchor.z
    pedBounds.high = root.z + maximum.z - anchor.z
    pedBounds.ground = pedBounds.low
    -- With bone framing on, the box is only a stand-in while the skeleton streams in.
    return Config.camera.frameToBones == false
end

-- Config.camera.holdStill: a frozen ped still plays its idle animation, so a
-- camera re-aimed at its spine and head bones every frame sways with every
-- breath and weight shift, and the ped looks like it is moving in place. Held
-- still, the anchor and bounds are measured once per ped and model (retried for
-- a few frames while the skeleton streams in) and the view stays put.
local MEASURE_TRIES = 30
local held = { ped = nil, model = nil, anchor = nil, root = nil, heading = nil, settled = false, tries = 0 }
-- The anchor is a world position, so it is only valid while the ped stays where
-- it was measured. A ped that lands, is snapped to the ground or is moved after
-- the menu opened (character creation places it a moment before the session)
-- leaves a stale anchor behind, and the tight face view (30 degrees at 0.65 m)
-- is then aimed well above the head. Past this distance it is measured again.
local MOVED_EPSILON = 0.05

local function remeasure()
    held.settled, held.tries = false, 0
end

local function movedFrom(root, ped)
    if not root or type(GetEntityCoords) ~= 'function' then return false end
    local now = GetEntityCoords(ped)
    if not (now and now.x and now.y and now.z) then return false end
    local dx, dy, dz = now.x - root.x, now.y - root.y, now.z - root.z
    return dx * dx + dy * dy + dz * dz > MOVED_EPSILON * MOVED_EPSILON
end

local function frameAnchor(ped)
    if Config.camera.holdStill == false then
        measurePedBounds(ped)
        return cameraAnchor(ped)
    end
    local model = GetEntityModel(ped)
    if held.ped ~= ped or held.model ~= model then
        held.ped, held.model = ped, model
        remeasure()
    elseif held.settled and movedFrom(held.root, ped) then
        remeasure()
    end
    if not held.settled then
        held.tries = held.tries + 1
        held.settled = measurePedBounds(ped) == true or held.tries >= MEASURE_TRIES
        held.anchor = cameraAnchor(ped)
        held.root = type(GetEntityCoords) == 'function' and GetEntityCoords(ped) or nil
    end
    return held.anchor
end

-- Heading the orbit is measured from. Held still it is the heading the menu
-- opened with, which the front-facing start angle was solved for, so the camera
-- stays on the same side of the ped for the whole session whatever the ped's
-- heading does afterwards.
local function frameHeading(ped)
    if Config.camera.holdStill ~= false and held.heading and held.ped == ped then return held.heading end
    return GetEntityHeading(ped)
end

-- Idle fidget animations (looking around, shifting weight) are paused while a
-- menu holds the ped still, and allowed again when it closes. The player's own
-- on-foot behaviour is replaced by a stand-still task and head IK is switched
-- off as well: left alone, the player ped turns its head and upper body to look
-- at the camera, so while the orbit swings round it the ped keeps turning and
-- seems to move in place. Freezing the ped does not stop that.
local stilledPed
local pedTurned = false -- Camera.rotatePed changed the heading since the camera started

local function exists(ped)
    return ped and (type(DoesEntityExist) ~= 'function' or DoesEntityExist(ped))
end

local function setAmbientAnims(ped, enabled)
    if not exists(ped) then return end
    if type(SetPedCanPlayAmbientAnims) == 'function' then SetPedCanPlayAmbientAnims(ped, enabled) end
    if type(SetPedCanPlayAmbientBaseAnims) == 'function' then SetPedCanPlayAmbientBaseAnims(ped, enabled) end
end

local function holdPed(ped)
    if not exists(ped) then return end
    setAmbientAnims(ped, false)
    if type(TaskStandStill) == 'function' then TaskStandStill(ped, -1) end
    if type(SetPedCanHeadIk) == 'function' then SetPedCanHeadIk(ped, false) end
    stilledPed = ped
end

-- A ped that went down meanwhile is left to the death handling, which plays its
-- own animation: clearing tasks would stand it up for a moment.
local function pedDown(ped)
    if type(IsPedDeadOrDying) == 'function' and IsPedDeadOrDying(ped, true) then return true end
    if type(IsPedRagdoll) == 'function' and IsPedRagdoll(ped) then return true end
    local state = LocalPlayer and LocalPlayer.state
    return state ~= nil and state.emsDown == true
end

local function releasePed()
    local ped = stilledPed
    stilledPed = nil
    if not exists(ped) then return end
    setAmbientAnims(ped, true)
    if type(SetPedCanHeadIk) == 'function' then SetPedCanHeadIk(ped, true) end
    if type(ClearPedTasks) == 'function' and not pedDown(ped) then ClearPedTasks(ped) end
end

-- Keeps a camera height at least `minAbove` metres above the floor
-- (Config.camera.minHeightAboveGround).
local function clampAboveGround(z, groundZ, minAbove)
    return math.max(z, groundZ + (tonumber(minAbove) or 0.0))
end

-- Look-at and camera heights for a zone, relative to the anchor, kept inside
-- the ped. A zone with `track` ("head" or "feet") is centred on that bone plus
-- `trackOffset` instead of on the spine, so it follows the model's real height.
-- The camera keeps the preset's height above its look-at point but never goes
-- below the floor.
local function zoneHeights(zoneCfg)
    local base = zoneCfg.boneOffset.z
    local tracked = zoneCfg.track == 'head' and pedBounds.head or zoneCfg.track == 'feet' and pedBounds.feet
    if tracked then base = tracked + (zoneCfg.trackOffset or 0.0) end

    local target = clamp(base, pedBounds.low, pedBounds.high - pedBounds.margin)
    local lowest = math.min(pedBounds.high, math.max(pedBounds.low, pedBounds.ground + (Config.camera.minHeightAboveGround or 0.0)))
    local height = clamp(target + zoneCfg.camOffset.z, lowest, pedBounds.high)
    return target, height
end

-- Floor height under the ped for the live camera clamp: the foot-bone floor,
-- raised to the real ground under the camera when the engine finds one close to
-- the ped (so a slope or step cannot put the camera under it either).
local function floorZ(anchor, camX, camY)
    local floor = anchor.z + pedBounds.ground
    if type(GetGroundZFor_3dCoord) == 'function' then
        local found, groundZ = GetGroundZFor_3dCoord(camX, camY, anchor.z, false)
        if found and groundZ and math.abs(groundZ - floor) < 1.0 then floor = math.max(floor, groundZ) end
    end
    return floor
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
        -- The occlusion lift may raise the camera, but never above the head.
        pedCoords.z + math.min(height + lift, math.max(height, pedBounds.high))
    )
end

local function resolveOcclusion()
    if not (pedRef and DoesEntityExist(pedRef)) then return end

    local zoneCfg = Config.camera.zones[target.zone] or Config.camera.zones.full
    local pedCoords = frameAnchor(pedRef)
    local heading = frameHeading(pedRef)
    local radius = goalRadius(zoneCfg)
    local targetOffset, height = zoneHeights(zoneCfg)
    local maxSwing = tonumber(Config.camera.occlusionMaxSwing) or 55.0
    -- A capsule that starts on the floor always reports a hit, which on the
    -- shoes view (look-at a hand's width above the floor) blocked every front
    -- angle and sent the camera round to the side or the back. Both ends of the
    -- trace stay a capsule radius clear of the floor.
    local clearZ = pedCoords.z + pedBounds.ground + CAMERA_TRACE_RADIUS + 0.05

    -- Traced from the point the camera is actually aimed at, not the ped's
    -- feet: a waist-high shop counter is not between a face-framed camera and
    -- the ped's head, and tracing from floor level would insist that it is.
    local subject = vector3(pedCoords.x, pedCoords.y, math.max(pedCoords.z + targetOffset, clearZ))

    local firstImpact
    for index, angle in ipairs(CAMERA_FAN_ANGLES) do
        -- Config.camera.occlusionMaxSwing keeps the camera in front of the ped:
        -- angles further round than this (the side and rear candidates) are not tried.
        if math.abs(angle) <= maxSwing then
            local lift = index > 5 and 0.65 or 0.0
            local candidate = candidatePoint(pedCoords, heading, radius, height, target.angle + angle, lift)
            candidate = vector3(candidate.x, candidate.y, math.max(candidate.z, clearZ))
            local blocked, impact = traceCameraPath(subject, candidate)
            if blocked == false then
                occlusion.angle, occlusion.lift, occlusion.radiusScale = angle, lift, 1.0
                return
            end
            if blocked and not firstImpact then firstImpact = impact end
        end
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

-- Orbit angle that puts the camera in front of a ped facing `heading`. The orbit
-- places the camera at (-sin(heading + angle), -cos(heading + angle)) around the
-- ped, which only lands in front of it for headings of 90 and 270 degrees; at
-- other headings an angle of 0 shows the ped side-on or from behind. Solving
-- the two for the ped's forward vector (-sin(heading), cos(heading)) gives
-- 180 - 2 * heading. Rotation input is relative, so drag direction is unchanged.
local function frontAngle(heading)
    return (180.0 - 2.0 * (tonumber(heading) or 0.0)) % 360.0
end

-- Config.camera.initialView: 'front' faces the ped's face, anything else keeps
-- the historical angle of 0 relative to the ped's heading.
local function initialAngle(heading)
    if Config.camera.initialView == 'current' then return 0.0 end
    return frontAngle(heading)
end

-- Config.camera.initialPreset, falling back to the whole-body preset when the
-- configured name is not one of Config.camera.zones.
local function initialZone()
    local name = Config.camera.initialPreset
    if type(name) == 'string' and Config.camera.zones[name] then return name end
    return 'full'
end

function Camera.start(ped)
    if cam then Camera.stop() end
    pedRef = ped
    active = true
    held.ped = nil
    frameAnchor(ped)
    if Config.camera.holdStill ~= false then holdPed(ped) end

    local zone = initialZone()
    local first = Config.camera.zones[zone]
    local firstLook, firstHeight = zoneHeights(first)
    held.heading = GetEntityHeading(ped)
    local angle = initialAngle(held.heading)
    state.radius, state.height, state.fov, state.angle = first.camOffset.y, firstHeight, first.fov, angle
    state.look = firstLook
    applied.angle, applied.lift, applied.radiusScale = 0.0, 0.0, 1.0
    target.zone, target.angle, target.zoomOffset = zone, angle, 0.0
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
            -- Everything that makes up the view -- position, look-at height, fov and
            -- the occlusion swing -- is eased with the same frame-rate independent
            -- rate, which settles in about Config.camera.transitionMs. The look-at
            -- height used to jump to the new category while the camera was still
            -- travelling, and the occlusion swing was applied in a single frame.
            local zoomRate = settleRate(dt)
            state.radius = lerp(state.radius, goalRadius(zoneCfg), zoomRate)
            local targetOffset, goalHeight = zoneHeights(zoneCfg)
            state.height = lerp(state.height, goalHeight, zoomRate)
            state.look = lerp(state.look, targetOffset, zoomRate)
            state.fov = lerp(state.fov, zoneCfg.fov, zoomRate)
            state.angle = lerpAngle(state.angle, target.angle, math.min(1.0, dt * 6.0))
            applied.angle = lerpAngle(applied.angle, occlusion.angle % 360.0, zoomRate)
            applied.lift = lerp(applied.lift, occlusion.lift, zoomRate)
            applied.radiusScale = lerp(applied.radiusScale, occlusion.radiusScale, zoomRate)

            if pedRef and DoesEntityExist(pedRef) then
                -- Re-measured when the model changes (a saved outfit on the other
                -- freemode model), otherwise held still (Config.camera.holdStill).
                local pedCoords = frameAnchor(pedRef)
                local heading = frameHeading(pedRef)
                local targetHeight = pedCoords.z + state.look
                local camPoint = candidatePoint(
                    pedCoords, heading,
                    state.radius * applied.radiusScale, state.height,
                    state.angle + applied.angle, applied.lift
                )

                local camZ = camPoint.z
                if (Config.camera.minHeightAboveGround or 0.0) > 0.0 then
                    camZ = clampAboveGround(camZ, floorZ(pedCoords, camPoint.x, camPoint.y), Config.camera.minHeightAboveGround)
                end

                SetCamCoord(cam, camPoint.x, camPoint.y, camZ)
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
    -- The ped may have settled since the menu opened; frame the new view from
    -- a fresh reading of its bones.
    remeasure()
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

---Turns the ped itself (capture rotate mode) instead of orbiting the camera: the
---camera is held still (Config.camera.holdStill), so it never leaves the spot the
---menu framed. Positive turns the ped the way a rightward drag on its front would.
---The heading the menu opened with is put back when the camera stops.
---@param deltaDeg number
function Camera.rotatePed(deltaDeg)
    deltaDeg = tonumber(deltaDeg)
    if not deltaDeg or deltaDeg ~= deltaDeg or not exists(pedRef) then return end
    SetEntityHeading(pedRef, (GetEntityHeading(pedRef) + deltaDeg) % 360.0)
    pedTurned = true
end

---Drag finished: stop the orbit at the angle it has reached instead of easing
---on towards a target the player is no longer pulling.
function Camera.rotateEnd()
    target.angle = state.angle % 360.0
end

---Frames a menu category (a clothing group like 'shoes' or a tattoo group like
---'Head') using Config.camera.categoryZones. Setting the zone also drops any
---wheel zoom. Does nothing unless Config.camera.resetOnCategoryChange is true
---(the default is false), so the player's manual camera is kept. Returns the zone now in effect.
---@param category string
---@return string
function Camera.setCategory(category)
    local zone = Config.camera.categoryZones[category]
    if Config.camera.resetOnCategoryChange and zone then Camera.setZone(zone) end
    return target.zone
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
    if pedTurned and held.heading and exists(pedRef) then SetEntityHeading(pedRef, held.heading) end
    pedTurned = false
    releasePed()
    if cam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    pedRef = nil
end

function Camera.currentZone()
    return target.zone
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
        zone = function() return target.zone end,
        zoneHeights = zoneHeights,
        setPedBounds = function(low, high)
            pedBounds.low, pedBounds.high, pedBounds.ground = low, high, low
            pedBounds.head, pedBounds.feet, pedBounds.margin = nil, nil, HEAD_MARGIN
        end,
        boneBounds = boneBounds,
        setBoneBounds = function(anchorZ, headZ, leftZ, rightZ)
            local bounds = boneBounds(anchorZ, headZ, leftZ, rightZ)
            if bounds then applyBounds(bounds) end
            return bounds ~= nil
        end,
        clampAboveGround = clampAboveGround,
        setZoomOffset = function(value) target.zoomOffset = value end,
        targetAngle = function() return target.angle end,
        frontAngle = frontAngle,
        initialAngle = initialAngle,
        initialZone = initialZone,
        setAngles = function(live, goal) state.angle, target.angle = live, goal end,
        frameAnchor = frameAnchor,
        settleRate = settleRate,
    }
end

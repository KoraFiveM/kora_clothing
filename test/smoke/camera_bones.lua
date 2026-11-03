-- Bone-based head/feet framing and the ground clamp. Pure arithmetic, no natives.
-- Anchor (spine) at z=1.0. A standing male is about head 1.68, feet 0.1; a
-- shorter female about head 1.55, feet 0.1, and the ped may be at any world z.
local H = dofile('test/harness.lua')

_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.Kora = { util = { clamp = function(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end } }

dofile('config.lua')
Config.testMode = true
dofile('client/camera.lua')
local runtime = Camera._testRuntime
local zones = Config.camera.zones

local function approx(actual, expected, message)
    H.ok(math.abs(actual - expected) < 1e-9, ('%s (expected %s, got %s)'):format(message, expected, actual))
end

H.equal(Config.camera.frameToBones, true, 'bone framing is on by default')
H.equal(Config.camera.minHeightAboveGround, 0.15, 'default ground clearance')
H.equal(zones.face.track, 'head')
H.equal(zones.shoes.track, 'feet')

for _, ped in ipairs({
    { name = 'male', anchor = 1.0, head = 1.68, foot = 0.1 },
    { name = 'female', anchor = 0.95, head = 1.55, foot = 0.08 },
    { name = 'tall', anchor = 1.1, head = 1.95, foot = 0.1 },
    { name = 'raised ground', anchor = 31.0, head = 31.55, foot = 30.08 },
}) do
    H.ok(runtime.setBoneBounds(ped.anchor, ped.head, ped.foot + 0.02, ped.foot), ped.name .. ' bones accepted')
    local headRel, footRel = ped.head - ped.anchor, ped.foot - ped.anchor

    local target, height = runtime.zoneHeights(zones.face)
    approx(target, headRel + zones.face.trackOffset, ped.name .. ': face looks at the head bone, not the chest')
    H.ok(target > headRel - 0.01, ped.name .. ': face look-at reaches head height')
    H.ok(height >= target and height <= headRel + 0.12 + 1e-9, ped.name .. ': face camera is at head height')

    target, height = runtime.zoneHeights(zones.shoes)
    approx(target, footRel + 0.01 + zones.shoes.trackOffset, ped.name .. ': shoes look at the midpoint of the foot bones')
    H.ok(height >= footRel - 0.1 + Config.camera.minHeightAboveGround - 1e-9, ped.name .. ': shoes camera is above the floor')

    -- Torso and legs are untouched by tracking.
    approx(runtime.zoneHeights(zones.torso), zones.torso.boneOffset.z, ped.name .. ': torso keeps its offset')
end

-- A zone with a camera offset pointing down is lifted to the clearance, not left under the floor.
runtime.setBoneBounds(1.0, 1.68, 0.1, 0.1)
local low = { boneOffset = zones.shoes.boneOffset, camOffset = vector3(0.0, 1.0, -0.5), fov = 35.0, track = 'feet', trackOffset = 0.0 }
local _, height = runtime.zoneHeights(low)
approx(height, (0.1 - 0.1 - 1.0) + 0.15, 'a downward camera offset is lifted to ground + minHeightAboveGround')
Config.camera.minHeightAboveGround = 0.4
_, height = runtime.zoneHeights(low)
approx(height, (0.1 - 0.1 - 1.0) + 0.4, 'a larger configured clearance is respected')
Config.camera.minHeightAboveGround = 0.15

-- Implausible skeleton readings (unstreamed ped, zero vectors) are rejected.
H.equal(runtime.boneBounds(0.0, 0.0, 0.0, 0.0), nil, 'zero bones are rejected')
H.equal(runtime.boneBounds(1.0, nil, 0.1, 0.1), nil, 'missing bones are rejected')

-- Box fallback keeps the old behaviour (tracked zones use boneOffset).
runtime.setPedBounds(-1.3, 0.7)
approx(runtime.zoneHeights(zones.shoes), math.max(-1.3, zones.shoes.boneOffset.z), 'fallback uses the spine offset')
local _, fallbackHeight = runtime.zoneHeights(zones.shoes)
H.ok(fallbackHeight >= -1.3 + 0.15 - 1e-9, 'fallback camera is above the box floor')

-- Live floor clamp.
approx(runtime.clampAboveGround(29.0, 30.0, 0.15), 30.15, 'camera under the ground is raised above it')
approx(runtime.clampAboveGround(31.0, 30.0, 0.15), 31.0, 'camera above the ground is left alone')
approx(runtime.clampAboveGround(31.0, 30.0, 'x'), 31.0, 'bad clearance is treated as zero')

-- Config.camera.holdStill: the idle animation sways the spine and head bones;
-- held still, the camera is aimed from one measurement instead of chasing them.
local sway, model = 0.0, 'mp_m_freemode_01'
local bones = { [24816] = 1.0, [31086] = 1.68, [14201] = 0.12, [52301] = 0.1 }
_G.GetPedBoneCoords = function(_, bone) return { x = 5.0 + sway, y = 2.0, z = bones[bone] + sway } end
_G.GetEntityModel = function() return model end
H.equal(Config.camera.holdStill, true, 'held still by default')
local first = runtime.frameAnchor(7)
sway = 0.03
local later = runtime.frameAnchor(7)
H.equal(later.x, first.x, 'anchor does not follow the sway (x)')
H.equal(later.z, first.z, 'anchor does not follow the sway (z)')
model = 'mp_f_freemode_01'
H.ok(runtime.frameAnchor(7).z ~= first.z, 'a new model is measured again')
H.ok(runtime.frameAnchor(8).x == 5.03, 'so is a new ped')
Config.camera.holdStill = false
sway = 0.05
approx(runtime.frameAnchor(8).z, 1.05, 'holdStill off follows the bones every frame as before')
Config.camera.holdStill = true

-- Idle fidgets are paused for the menu and allowed again when it closes.
local ambient = {}
_G.SetPedCanPlayAmbientAnims = function(ped, on) ambient[#ambient + 1] = { 'anims', ped, on } end
_G.SetPedCanPlayAmbientBaseAnims = function(ped, on) ambient[#ambient + 1] = { 'base', ped, on } end
_G.DoesEntityExist = function() return true end
_G.GetEntityHeading = function() return 0.0 end
_G.CreateCam = function() return 1 end
_G.SetCamActive, _G.RenderScriptCams, _G.DestroyCam = function() end, function() end, function() end
_G.CreateThread = function() end
Camera.start(9)
H.equal(#ambient, 2, 'both ambient animation kinds paused')
H.equal(ambient[1][2], 9); H.equal(ambient[1][3], false); H.equal(ambient[2][3], false)
Camera.stop()
H.equal(#ambient, 4, 'and allowed again on close')
H.equal(ambient[3][3], true); H.equal(ambient[4][3], true)

-- The player ped turns its head and body to look at the camera unless it is
-- tasked to stand still with head IK off; both are handed back on close.
local tasks = {}
local dead = false
_G.TaskStandStill = function(ped, ms) tasks[#tasks + 1] = { 'stand', ped, ms } end
_G.SetPedCanHeadIk = function(ped, on) tasks[#tasks + 1] = { 'headIk', ped, on } end
_G.ClearPedTasks = function(ped) tasks[#tasks + 1] = { 'clear', ped } end
_G.IsPedDeadOrDying = function() return dead end
Camera.start(9)
H.equal(tasks[1][1], 'stand', 'the ped is tasked to stand still')
H.equal(tasks[1][2], 9); H.equal(tasks[1][3], -1, 'for as long as the menu is open')
H.equal(tasks[2][1], 'headIk'); H.equal(tasks[2][3], false, 'head IK is off so it does not follow the camera')
Camera.rotate(90.0)
H.equal(#tasks, 2, 'rotating never re-tasks the ped')
Camera.stop()
H.equal(tasks[3][1], 'headIk'); H.equal(tasks[3][3], true, 'head IK is back on close')
H.equal(tasks[4][1], 'clear'); H.equal(tasks[4][2], 9, 'and the stand-still task is cleared')
Camera.stop()
H.equal(#tasks, 4, 'a second stop does nothing')

tasks = {}
Camera.start(9)
dead = true
Camera.stop()
H.equal(#tasks, 3, 'a ped that went down keeps the death animation (tasks not cleared)')
dead = false
tasks = {}
_G.LocalPlayer = { state = { emsDown = true } }
Camera.start(9)
Camera.stop()
H.equal(#tasks, 3, 'nor while kora_ambulance reports the player down')
_G.LocalPlayer = nil

Config.camera.holdStill = false
tasks, ambient = {}, {}
Camera.start(9)
Camera.stop()
H.equal(#ambient, 0, 'holdStill off leaves the animations alone')
H.equal(#tasks, 0, 'and the ped tasks too')
Config.camera.holdStill = true

H.finish()

-- Transitions: the ease settles (~95%) in Config.camera.transitionMs at any frame rate.
H.equal(Config.camera.transitionMs, 500, 'default transition is 500 ms')
H.equal(Config.camera.occlusionMaxSwing, 55.0, 'occlusion may not swing past the front arc by default')
local function settle(fps)
    local remaining = 1.0
    for _ = 1, math.floor(fps * Config.camera.transitionMs / 1000 + 0.5) do
        remaining = remaining * (1.0 - runtime.settleRate(1 / fps))
    end
    return remaining
end
approx(settle(30), settle(144), 'settle time does not depend on frame rate')
H.ok(settle(60) < 0.06 and settle(60) > 0.04, 'about 95% of a change is done after transitionMs')
H.equal(Config.bucket.suppressClientPopulation, true, 'client population suppression is on by default')
H.equal(Config.rotateDragCursor, 'grabbing', 'drag cursor defaults to grabbing')
H.equal(Config.rotateHideCursor, true, 'cursor is hidden while rotating by default')

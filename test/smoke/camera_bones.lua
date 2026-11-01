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
    approx(target, footRel + zones.shoes.trackOffset, ped.name .. ': shoes look at the foot bones')
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

H.finish()

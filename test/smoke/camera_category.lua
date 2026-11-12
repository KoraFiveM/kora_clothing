-- Category -> camera zone mapping, the reset-on-category-change option, and the
-- height clamp that keeps the head framing on the ped.
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

-- Default: choosing a category does NOT move the camera (the player has full
-- camera control and the preset buttons); the framing below needs the option on.
H.equal(Config.camera.resetOnCategoryChange, false, 'default leaves the camera alone')
Camera.setZone('legs')
Camera.zoom(-5)
local keptZoom = runtime.zoomOffset()
H.equal(Camera.setCategory('shoes'), 'legs', 'default keeps the zone on a category change')
H.equal(runtime.zoomOffset(), keptZoom, 'and the manual zoom')
Camera.setZone('face')
H.equal(runtime.zone(), 'face', 'the preset buttons still move the camera')
H.equal(runtime.zoomOffset(), 0.0, 'and still drop the wheel zoom')
Config.camera.resetOnCategoryChange = true

local function frame(category)
    Camera.setZone('full') -- known starting point
    runtime.setZoomOffset(-1.0) -- manual wheel zoom to be cleared
    return Camera.setCategory(category)
end

H.equal(frame('Head'), 'face', 'a head tattoo frames the face')
H.equal(runtime.zoomOffset(), 0.0, 'and drops manual zoom')
H.equal(frame('Torso'), 'torso', 'a torso tattoo frames the torso')
H.equal(frame('Arms'), 'torso', 'arms fall back to the torso framing')
H.equal(frame('Legs'), 'legs')
H.equal(frame('shoes'), 'shoes', 'switching to shoes leaves the head framing')
H.equal(runtime.zoomOffset(), 0.0)
H.equal(frame('tops'), 'torso')
H.equal(frame('body'), 'face')

-- From the head zone straight to shoes, with zoom applied in between.
Camera.setCategory('Head')
Camera.zoom(-5)
H.ok(runtime.zoomOffset() ~= 0.0)
H.equal(Camera.setCategory('shoes'), 'shoes')
H.equal(runtime.zoomOffset(), 0.0, 'shoes starts from its own preset, not the stacked head zoom')

-- Unknown categories change nothing.
Camera.setZone('legs')
H.equal(Camera.setCategory('Nonsense'), 'legs')

-- Off: the manual camera is kept.
Config.camera.resetOnCategoryChange = false
Camera.setZone('face')
Camera.zoom(-5)
local zoom = runtime.zoomOffset()
H.equal(Camera.setCategory('shoes'), 'face', 'false keeps the current zone')
H.equal(runtime.zoomOffset(), zoom, 'and the manual zoom')
Config.camera.resetOnCategoryChange = true

-- Initial view: 'front' puts the camera in front of the ped at ANY heading,
-- 'current' keeps the old angle of 0.
local function cameraDotForward(heading, angle)
    local rad = math.rad(heading + angle)
    local cx, cy = -math.sin(rad), -math.cos(rad) -- offset used by candidatePoint
    local hr = math.rad(heading)
    return cx * -math.sin(hr) + cy * math.cos(hr)
end
H.equal(Config.camera.initialView, 'front', 'default starts face-on')
for _, heading in ipairs({ 0.0, 37.5, 90.0, 180.0, 271.0, 359.0 }) do
    local angle = runtime.initialAngle(heading)
    H.ok(angle >= 0.0 and angle < 360.0, 'angle is normalised at ' .. heading)
    H.ok(math.abs(cameraDotForward(heading, angle) - 1.0) < 1e-9, 'camera is in front at heading ' .. heading)
end
Config.camera.initialView = 'current'
H.equal(runtime.initialAngle(37.5), 0.0, "'current' keeps the old starting angle")
Config.camera.initialView = 'front'

H.equal(Config.camera.initialPreset, 'full', 'default preset is the whole body')
H.equal(runtime.initialZone(), 'full')
Config.camera.initialPreset = 'face'
H.equal(runtime.initialZone(), 'face', 'a configured preset is used')
Config.camera.initialPreset = 'nope'
H.equal(runtime.initialZone(), 'full', 'an unknown preset falls back to full')
Config.camera.initialPreset = 'full'

-- Every mapped zone exists.
for category, zone in pairs(Config.camera.categoryZones) do
    H.ok(Config.camera.zones[zone], category .. ' maps to a real zone')
end

-- The look-at point never rises above the head and the camera stays within the ped.
-- Each region is framed at its own height: head above chest above thighs above feet,
-- all inside a standing freemode ped (about -1.3 .. +0.65m around the spine anchor).
local zones = Config.camera.zones
H.ok(zones.face.boneOffset.z > zones.torso.boneOffset.z, 'head is framed above the torso')
H.ok(zones.torso.boneOffset.z > zones.legs.boneOffset.z, 'torso is framed above the legs')
H.ok(zones.legs.boneOffset.z > zones.shoes.boneOffset.z, 'legs are framed above the shoes')
H.ok(zones.face.boneOffset.z <= 0.65 - 0.15 + 1e-9, 'head look-at is not above the head')
H.ok(zones.shoes.boneOffset.z >= -1.3, 'shoes look-at is not below the feet')

runtime.setPedBounds(-1.3, 0.7)
local face = Config.camera.zones.face
local target, height = runtime.zoneHeights(face)
H.ok(target <= 0.7 - 0.15 + 1e-9, 'face look-at is below the top of the head')
H.ok(height <= 0.7 + 1e-9, 'face camera is not above the head')
target = runtime.zoneHeights(Config.camera.zones.shoes)
H.equal(target, Config.camera.zones.shoes.boneOffset.z, 'a zone inside the ped is untouched')
runtime.setPedBounds(-1.3, 5.0)
target, height = runtime.zoneHeights(face)
H.equal(target, face.boneOffset.z, 'a tall ped keeps the authored face framing')
H.equal(height, face.boneOffset.z + face.camOffset.z)

H.finish()

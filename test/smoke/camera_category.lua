-- Category -> camera zone mapping, the reset-on-category-change option, and the
-- height clamp that keeps the head framing on the ped.
local H = dofile('test/harness.lua')

_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.QB = { util = { clamp = function(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end } }

dofile('config.lua')
Config.testMode = true
dofile('client/camera.lua')
local runtime = Camera._testRuntime

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
H.equal(Config.camera.resetOnCategoryChange, true, 'default is on')

-- Every mapped zone exists.
for category, zone in pairs(Config.camera.categoryZones) do
    H.ok(Config.camera.zones[zone], category .. ' maps to a real zone')
end

-- The look-at point never rises above the head and the camera stays within the ped.
runtime.setPedBounds(-1.0, 0.7)
local face = Config.camera.zones.face
local target, height = runtime.zoneHeights(face)
H.ok(target <= 0.7 - 0.15 + 1e-9, 'face look-at is below the top of the head')
H.ok(height <= 0.7 + 1e-9, 'face camera is not above the head')
target = runtime.zoneHeights(Config.camera.zones.shoes)
H.equal(target, Config.camera.zones.shoes.boneOffset.z, 'a zone inside the ped is untouched')
runtime.setPedBounds(-1.0, 5.0)
target, height = runtime.zoneHeights(face)
H.equal(target, face.boneOffset.z, 'a tall ped keeps the authored face framing')
H.equal(height, face.boneOffset.z + face.camOffset.z)

H.finish()

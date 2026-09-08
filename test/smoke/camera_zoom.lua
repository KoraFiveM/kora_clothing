-- Coverage for the free mouse-wheel zoom's clamping. The NUI sends wheel
-- NOTCHES, not metres, and can send a great many of them in a single flick --
-- so the arithmetic that turns those into a camera radius is the whole rule
-- here, and it is plain Lua (no natives, no live camera), which is exactly
-- what this suite can exercise.
--
-- Two clamps matter and they are not the same clamp. The RADIUS clamp keeps
-- the camera between Config.camera.zoom.min/max. The OFFSET clamp is what
-- stops the accumulated wheel travel running away past that bound while the
-- wheel keeps spinning -- without it, the first notch back the other way does
-- nothing at all until it has unwound however far the offset overshot.
local H = dofile('test/harness.lua')

_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end

dofile('config.lua')
Config.testMode = true
dofile('client/camera.lua')

local runtime = Camera._testRuntime
local bounds = Config.camera.zoom
local full = Config.camera.zones.full

local function resetZoom() runtime.setZoomOffset(0.0) end

local function approx(actual, expected, message)
    H.ok(math.abs(actual - expected) < 1e-9, ('%s (expected %s, got %s)'):format(message, expected, actual))
end

-- Orbit angles are circular, not ordinary numbers. Crossing the 0° seam must
-- take the two-degree arc, not sweep nearly all the way around in reverse.
approx(runtime.lerpAngle(359.0, 1.0, 0.25), 359.5, 'orbit interpolation crosses 360° on the short clockwise arc')
approx(runtime.lerpAngle(1.0, 359.0, 0.25), 0.5, 'orbit interpolation crosses 0° on the short counter-clockwise arc')

-- A zone preset with nothing added is the preset, untouched.
resetZoom()
approx(runtime.goalRadius(full), full.camOffset.y, 'no wheel input leaves the zone preset radius exactly as authored')

-- One notch out, one notch in: the offset is metres-per-notch, so this is the
-- only place the step is allowed to matter.
resetZoom()
Camera.zoom(1)
approx(runtime.zoomOffset(), bounds.step, 'one notch out adds exactly one step of offset')
approx(runtime.goalRadius(full), full.camOffset.y + bounds.step, 'the offset lands on top of the selected zone, not instead of it')
Camera.zoom(-1)
approx(runtime.zoomOffset(), 0.0, 'a notch back the other way cancels it')

-- A flick of the wheel: far more travel than the bounds allow, in one go.
resetZoom()
Camera.zoom(-500)
H.ok(runtime.goalRadius(full) >= bounds.min, 'zooming all the way in never goes below Config.camera.zoom.min')
H.equal(runtime.goalRadius(full), bounds.min, 'zooming all the way in lands exactly on the floor')
approx(runtime.zoomOffset(), bounds.min - full.camOffset.y, 'the offset is clamped against the current zone, so it never describes a radius the goal clamp would reject')

-- The payoff of clamping the offset as well: one notch the other way has to
-- visibly move the camera immediately. If only the radius were clamped, the
-- offset would sit metres past the floor and this notch would change nothing.
Camera.zoom(1)
H.ok(runtime.goalRadius(full) > bounds.min, 'a single notch back out immediately moves the camera off the floor')

resetZoom()
Camera.zoom(500)
H.equal(runtime.goalRadius(full), bounds.max, 'zooming all the way out lands exactly on the ceiling')
Camera.zoom(-1)
H.ok(runtime.goalRadius(full) < bounds.max, 'a single notch back in immediately moves the camera off the ceiling')

-- Garbage from the NUI must not poison the offset -- an NaN offset would make
-- every subsequent goalRadius NaN and send the camera to nowhere permanently.
resetZoom()
Camera.zoom(1)
local before = runtime.zoomOffset()
Camera.zoom('not-a-number')
Camera.zoom(nil)
Camera.zoom(0 / 0)
approx(runtime.zoomOffset(), before, 'non-numeric and NaN deltas are ignored rather than accumulated')

-- Every zone has to be reachable at its authored framing: a preset whose own
-- radius sat outside the zoom bounds could never be shown as authored.
for name, zone in pairs(Config.camera.zones) do
    resetZoom()
    approx(runtime.goalRadius(zone), zone.camOffset.y, ('the %s preset radius is inside the zoom bounds'):format(name))
end

-- A preset is a jump-TO, so selecting one discards accumulated wheel travel --
-- otherwise pressing "Full body" while zoomed right in still shows a close-up.
resetZoom()
Camera.zoom(-10)
H.ok(runtime.zoomOffset() < 0.0, 'the wheel accumulated an offset to discard')
Camera.setZone('face')
approx(runtime.zoomOffset(), 0.0, 'picking a zone preset resets the free-zoom offset')
approx(runtime.goalRadius(Config.camera.zones.face), Config.camera.zones.face.camOffset.y, 'so the preset lands on its own authored framing')

Camera.setZone('not-a-real-zone')
approx(runtime.goalRadius(Config.camera.zones.face), Config.camera.zones.face.camOffset.y, 'an unknown zone name is ignored entirely')

H.finish()

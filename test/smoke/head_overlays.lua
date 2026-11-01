-- Eyebrows (overlay 2) and facial hair (overlay 1): config gating, defaults for
-- old saves, the barber/creator merge, and the client applying them.
local H = dofile('test/harness.lua')

_G.GetCurrentResourceName = function() return 'kora_clothing' end
_G.AddEventHandler = function() end
_G.RegisterNetEvent = function() end
local callbacks = {}
_G.RegisterNUICallback = function(name, fn) callbacks[name] = fn end
_G.CreateThread = function() end
_G.exports = setmetatable({}, { __call = function() end, __index = function() return function() end end })
_G.PlayerId = function() return 1 end
_G.GetPlayerServerId = function() return 1 end
_G.LocalPlayer = { state = {} }
_G.AddStateBagChangeHandler = function() end
_G.PlayerPedId = function() return 1 end
_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.GetNumberOfPedDrawableVariations = function() return 0 end
_G.GetNumberOfPedPropDrawableVariations = function() return 0 end
_G.ClearPedProp = function() end
_G.SetPedHairColor = function() end
_G.GetNumHairColors = function() return 64 end
_G.GetPedHairRgbColor = function() return 0, 0, 0 end
_G.ClearPedDecorations = function() end
_G.GetPedDrawableVariation = function() return 0 end
_G.GetPedTextureVariation = function() return 0 end
_G.GetPedPropIndex = function() return -1 end
_G.SetPedHeadBlendData = function() end

local overlays, colors = {}, {}
_G.SetPedHeadOverlay = function(_, id, style, opacity) overlays[id] = { style = style, opacity = opacity } end
_G.SetPedHeadOverlayColor = function(_, id, _, color) colors[id] = color end

dofile('config.lua')
Config.testMode = true
dofile('shared/components.lua')
_G.RegisterCommand = _G.RegisterCommand or function() end
_G.TriggerEvent = _G.TriggerEvent or function() end
dofile('client/client.lua')
local runtime = QBClothing._testRuntime

-- Defaults: both overlays on for creator and barber.
for _, key in ipairs({ 'eyebrows', 'facialHair' }) do
    H.ok(Shared.headOverlayEnabled(Config.services.creation, key), key .. ' is on in the creator by default')
    H.ok(Shared.headOverlayEnabled(Config.services.barber, key), key .. ' is on at the barber by default')
    H.ok(Shared.headOverlayEnabled(Config.services.hairdresser, key), key .. ' is on at the hairdresser by default')
    H.ok(not Shared.headOverlayEnabled(Config.services.clothing, key), key .. ' is never on in a clothing shop')
end

-- An old save (skinTone + beard only) loads with defaults for everything new.
local old = Shared.sanitiseHead({ skinTone = 7, beard = 3 })
H.equal(old.beard, 3)
H.equal(old.beardOpacity, 1.0, 'old saves get full opacity')
H.equal(old.beardColor, -1, 'old saves keep following the hair colour')
H.equal(old.eyebrows, -1, 'old saves have no eyebrow overlay')
H.equal(Shared.sanitiseHead(nil).skinTone, 0)
local clamped = Shared.sanitiseHead({ eyebrows = 99, eyebrowsOpacity = 5, eyebrowsColor = 500, beard = -9, beardOpacity = 0 / 0 })
H.equal(clamped.eyebrows, 33)
H.equal(clamped.eyebrowsOpacity, 1.0)
H.equal(clamped.eyebrowsColor, Shared.maxHairColorIndex)
H.equal(clamped.beard, -1)
H.equal(clamped.beardOpacity, 1.0, 'NaN opacity falls back to the default')

-- Chest hair is head overlay 10 and is saved and re-applied like the others.
H.ok(Shared.headOverlayEnabled(Config.services.barber, 'chestHair'), 'chest hair is on at the barber by default')
H.ok(not Shared.headOverlayEnabled(Config.services.clothing, 'chestHair'), 'chest hair is never on in a clothing shop')
H.equal(Shared.sanitiseHead({ chestHair = 99 }).chestHair, 15)
H.equal(Shared.sanitiseHead({}).chestHair, -1, 'old saves have no chest hair')
overlays, colors = {}, {}
runtime.applySkin(1, { hairColor = 5, head = { chestHair = 3, chestHairOpacity = 0.6, chestHairColor = 12 } }, 'mp_m_freemode_01')
H.equal(overlays[10].style, 3)
H.equal(overlays[10].opacity, 0.6)
H.equal(colors[10], 12)

-- Save/load round trip through the client: apply, snapshot, sanitise, apply again.
local head = { skinTone = 4, beard = 5, beardOpacity = 0.5, beardColor = 9, eyebrows = 12, eyebrowsOpacity = 0.8, eyebrowsColor = -1 }
runtime.applySkin(1, { head = head }, 'mp_m_freemode_01')
H.equal(overlays[1].style, 5)
H.equal(overlays[1].opacity, 0.5)
H.equal(colors[1], 9)
H.equal(overlays[2].style, 12, 'eyebrows are applied to head overlay 2')
H.equal(overlays[2].opacity, 0.8)
H.equal(colors[2], 0, 'colour -1 follows the hair colour (index 0 here)')
local saved = Shared.sanitiseHead(runtime.currentSkinSnapshot(1).head)
for key, value in pairs(head) do H.equal(saved[key], value, 'round trip keeps ' .. key) end
overlays, colors = {}, {}
runtime.applySkin(1, { head = saved }, 'mp_m_freemode_01')
H.equal(overlays[2].style, 12)

-- No overlay -> no colour call, and the overlay is cleared.
overlays, colors = {}, {}
runtime.applySkin(1, { head = {} }, 'mp_m_freemode_01')
H.equal(overlays[1].style, -1)
H.equal(overlays[2].style, -1)
H.equal(colors[2], nil)

-- Barber merge: overlays editable, skin tone kept, disabled overlay kept.
local before = { skinTone = 10, beard = -1, eyebrows = 2 }
local request = { skinTone = 40, beard = 7, eyebrows = 20 }
local merged = Shared.mergeHead(Config.services.barber, before, request)
H.equal(merged.skinTone, 10, 'barber cannot change skin tone')
H.equal(merged.beard, 7)
H.equal(merged.eyebrows, 20)
Config.headOverlays.eyebrows.barber = false
merged = Shared.mergeHead(Config.services.barber, before, request)
H.equal(merged.eyebrows, 2, 'eyebrows=false at the barber keeps the saved eyebrows')
H.equal(merged.beard, 7)
merged = Shared.mergeHead(Config.services.creation, before, request)
H.equal(merged.skinTone, 40, 'creation edits skin tone')
H.equal(merged.eyebrows, 20, 'barber=false does not affect creation')
Config.headOverlays.facialHair.creator = false
merged = Shared.mergeHead(Config.services.creation, before, request)
H.equal(merged.beard, -1, 'facialHair.creator=false ignores the requested beard')
Config.headOverlays.eyebrows.barber, Config.headOverlays.facialHair.creator = true, true

-- Payload: flags follow the config live; nil when nothing is editable.
local payload = runtime.headPayload('barber')
H.equal(payload.skinToneEditable, false)
H.ok(payload.overlays.eyebrows and payload.overlays.facialHair)
H.equal(runtime.headPayload('clothing'), nil, 'clothing shops get no head controls')
Config.headOverlays.eyebrows.barber = false
H.equal(runtime.headPayload('barber').overlays.eyebrows, false, 'false hides the category')
Config.headOverlays.facialHair.barber = false
Config.headOverlays.chestHair.barber = false
H.equal(runtime.headPayload('barber'), nil, 'nothing editable means no payload')
H.equal(runtime.headPayload('creation').skinToneEditable, true)
Config.headOverlays.eyebrows.barber, Config.headOverlays.facialHair.barber = true, true
Config.headOverlays.chestHair.barber = true

-- Eyebrow colour is independent of hair colour by default (male and female
-- freemode peds take the same path), and Config can lock it back to the hair.
H.equal(Config.headOverlays.eyebrows.followHairColor, false, "eyebrow colour is independent by default")
H.equal(Shared.overlayFollowsHair('eyebrows'), false)
H.equal(Shared.overlayFollowsHair('facialHair'), false)
for _, model in ipairs({ 'mp_m_freemode_01', 'mp_f_freemode_01' }) do
    overlays, colors = {}, {}
    runtime.applySkin(1, { hairColor = 5, hairHighlight = 6, head = { eyebrows = 4, eyebrowsColor = 17 } }, model)
    H.equal(colors[2], 17, model .. ": picked eyebrow colour is not the hair colour")
    local snap = Shared.sanitiseHead(runtime.currentSkinSnapshot(1).head)
    H.equal(snap.eyebrowsColor, 17, model .. ": eyebrow colour is saved")
    overlays, colors = {}, {}
    runtime.applySkin(1, { hairColor = 5, hairHighlight = 6, head = snap }, model)
    H.equal(colors[2], 17, model .. ": eyebrow colour is loaded back")
end
H.equal(runtime.headPayload('barber').overlayColors.eyebrows, true, "NUI gets the eyebrow palette")
H.equal(Shared.mergeHead(Config.services.barber, { eyebrows = 1 }, { eyebrows = 2, eyebrowsColor = 30 }).eyebrowsColor, 30)

Config.headOverlays.eyebrows.followHairColor = true
overlays, colors = {}, {}
runtime.applySkin(1, { hairColor = 5, hairHighlight = 6, head = { eyebrows = 4, eyebrowsColor = 17, beard = 2, beardColor = 9 } }, 'mp_f_freemode_01')
H.equal(colors[2], 5, "followHairColor puts eyebrows on the primary hair colour")
H.equal(colors[1], 9, "facial hair keeps its own colour")
H.equal(runtime.headPayload('creation').overlayColors.eyebrows, false, "NUI hides the eyebrow palette")
H.equal(Shared.mergeHead(Config.services.creation, {}, { eyebrows = 2, eyebrowsColor = 30 }).eyebrowsColor, -1, "no stale colour is stored")
Config.headOverlays.eyebrows.followHairColor = false

H.finish()

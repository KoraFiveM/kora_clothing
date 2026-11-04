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

-- Every overlay can be locked to the hair colour from Config (the menu has no button for it).
for _, key in ipairs({ 'facialHair', 'chestHair' }) do
    H.equal(Config.headOverlays[key].followHairColor, false, key .. ' colour is independent by default')
    Config.headOverlays[key].followHairColor = true
    H.equal(Shared.overlayFollowsHair(key), true, key .. ' can follow the hair colour')
    H.equal(runtime.headPayload('barber').overlayColors[key], false, key .. ' palette hidden when locked')
    Config.headOverlays[key].followHairColor = false
    H.equal(runtime.headPayload('barber').overlayColors[key], true)
end

-- Make-up (overlays 4 blush 5 lipstick 8): own palette (colour type 2), creator-only by default.
for _, key in ipairs({ 'makeup', 'blush', 'lipstick' }) do
    H.ok(Shared.headOverlayEnabled(Config.services.creation, key), key .. ' is on in the creator by default')
    H.ok(not Shared.headOverlayEnabled(Config.services.barber, key), key .. ' is off at the barber by default')
    H.ok(not Shared.headOverlayEnabled(Config.services.clothing, key), key .. ' is never on in a clothing shop')
    H.equal(Shared.overlayFollowsHair(key), false, key .. ' never follows the hair colour')
end
H.equal(Shared.sanitiseHead({}).makeup, -1, 'old saves have no make-up')
H.equal(Shared.sanitiseHead({ makeup = 999 }).makeup, 74)
H.equal(Shared.sanitiseHead({ blush = 999 }).blush, 6)
H.equal(Shared.sanitiseHead({ lipstick = 999 }).lipstick, 9)
local overlayCalls, colorCalls = {}, {}
_G.SetPedHeadOverlay = function(_, id, style, opacity) overlayCalls[id] = { style = style, opacity = opacity } end
_G.SetPedHeadOverlayColor = function(_, id, colorType, color, second) colorCalls[id] = { colorType = colorType, color = color, second = second } end
runtime.applySkin(1, { hairColor = 5, head = { makeup = 10, makeupOpacity = 0.7, makeupColor = 21, lipstick = 3, beard = 2, beardColor = 9 } }, 'mp_f_freemode_01')
H.equal(overlayCalls[4].style, 10, 'make-up is head overlay 4')
H.equal(overlayCalls[4].opacity, 0.7)
H.equal(colorCalls[4].colorType, 2, 'make-up colour uses colour type 2')
H.equal(colorCalls[4].color, 21)
H.equal(overlayCalls[8].style, 3, 'lipstick is head overlay 8')
H.equal(colorCalls[8].color, 0, 'an unset make-up colour is the first make-up colour, not the hair colour')
H.equal(overlayCalls[5].style, -1, 'blush off')
H.equal(colorCalls[1].colorType, 1, 'facial hair keeps colour type 1')
local snap = Shared.sanitiseHead(runtime.currentSkinSnapshot(1).head)
H.equal(snap.makeup, 10, 'make-up round trips')
H.equal(snap.makeupColor, 21)
-- The creator payload carries the make-up palette, built from the game's make-up colours.
H.equal(type(runtime.headPayload('creation').makeupPalette), 'table', 'the creator payload has a make-up palette')
H.equal(#runtime.headPayload('creation').makeupPalette, 0, 'no make-up natives: empty palette')
_G.GetNumMakeupColors = function() return 64 end
_G.GetPedMakeupRgbColor = function(index) return index, 2, 3 end
local palette = runtime.headPayload('creation').makeupPalette
H.equal(#palette, 64)
H.equal(palette[6].index, 5)
H.equal(palette[6].r, 5)
H.equal(runtime.headPayload('barber').makeupPalette, nil, 'no palette where no make-up overlay is editable')
Config.headOverlays.makeup.barber = true
H.equal(Shared.mergeHead(Config.services.barber, {}, { makeup = 4 }).makeup, 4, 'make-up at the barber when enabled')
Config.headOverlays.makeup.barber = false
H.equal(Shared.mergeHead(Config.services.barber, {}, { makeup = 4 }).makeup, -1, 'make-up ignored at the barber by default')
Config.headOverlays.lipstick.creator = false
H.equal(Shared.mergeHead(Config.services.creation, {}, { lipstick = 4 }).lipstick, -1, 'lipstick.creator=false ignores the request')
Config.headOverlays.lipstick.creator = true

-- Heritage: auto parents (-1) reproduce the old blend; picked parents blend by the saved mixes.
local old = Shared.sanitiseHead({ skinTone = 7 })
H.equal(old.shapeFirst, -1, 'old saves have auto parents')
H.equal(old.skinSecond, -1)
H.equal(old.shapeMix, 0.5)
local wild = Shared.sanitiseHead({ shapeFirst = 99, shapeSecond = -9, skinFirst = 5.7, shapeMix = 3, skinMix = 0 / 0 })
H.equal(wild.shapeFirst, 45, 'parents clamp to 0..45')
H.equal(wild.shapeSecond, -1)
H.equal(wild.skinFirst, 5)
H.equal(wild.shapeMix, 1.0, 'mix clamps to 0..1')
H.equal(wild.skinMix, 0.5, 'NaN mix falls back to the default')
local blend
_G.SetPedHeadBlendData = function(...) blend = { ... } end
_G.GetPedDrawableVariation = function() return 22 end
runtime.applySkin(1, { head = { skinTone = 26 } }, 'mp_f_freemode_01')
H.equal(blend[2], 22, 'auto first shape parent is the face style')
H.equal(blend[3], 22, 'auto second shape parent is the face style')
H.equal(blend[5], 26, 'auto first skin parent is the skin tone')
H.equal(blend[6], 26)
runtime.applySkin(1, { head = { skinTone = 26, shapeFirst = 3, shapeSecond = 30, skinFirst = 4, skinSecond = 0, shapeMix = 0.25, skinMix = 0.75 } }, 'mp_f_freemode_01')
H.equal(blend[2], 3, 'father is the first shape parent')
H.equal(blend[3], 30, 'mother is the second shape parent')
H.equal(blend[5], 4)
H.equal(blend[6], 0, 'skin parent 0 is a real parent, not auto')
H.equal(blend[8], 0.25, 'shape mix')
H.equal(blend[9], 0.75, 'skin mix')
local savedHeritage = Shared.sanitiseHead(runtime.currentSkinSnapshot(1).head)
H.equal(savedHeritage.shapeSecond, 30, 'heritage round trips')
H.equal(savedHeritage.skinMix, 0.75)
_G.GetPedDrawableVariation = function() return 0 end

-- Heritage is creation-only and follows Config.heritage.creator.
H.equal(Config.heritage.creator, true, 'heritage is on in character creation by default')
H.equal(runtime.headPayload('creation').heritageEditable, true)
H.equal(runtime.headPayload('barber').heritageEditable, false, 'no heritage at the barber')
local request = { shapeFirst = 8, shapeSecond = 25, shapeMix = 0.9 }
H.equal(Shared.mergeHead(Config.services.creation, { shapeFirst = 1 }, request).shapeSecond, 25, 'creation edits heritage')
H.equal(Shared.mergeHead(Config.services.barber, { shapeFirst = 1 }, request).shapeFirst, 1, 'the barber keeps the saved heritage')
Config.heritage.creator = false
H.equal(runtime.headPayload('creation').heritageEditable, false)
H.equal(Shared.mergeHead(Config.services.creation, { shapeFirst = 1 }, request).shapeFirst, 1, 'heritage off keeps the saved parents')
Config.heritage.creator = true

H.finish()

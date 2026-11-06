-- Saved hair colour must survive a login: the tint is set AFTER the head blend
-- data (which drops an earlier tint), and re-asserted after the spawn flow
-- when Config.loginColourReapply is on, without clobbering a fitting room.
local H = dofile('test/harness.lua')

_G.GetCurrentResourceName = function() return 'kora_clothing' end
_G.AddEventHandler = function() end
local registeredNetEvents = {}
_G.RegisterNetEvent = function(name, cb) registeredNetEvents[name] = cb end
_G.RegisterNUICallback = function() end

-- Threads park at Wait; the test resumes them by hand.
local parked = {}
_G.CreateThread = function(fn)
    local co = coroutine.create(fn)
    local ok, err = coroutine.resume(co)
    if not ok then error(err, 0) end
    if coroutine.status(co) == 'suspended' then parked[#parked + 1] = co end
end
local function resumeParked()
    local list = parked
    parked = {}
    for _, co in ipairs(list) do
        local ok, err = coroutine.resume(co)
        if not ok then error(err, 0) end
        if coroutine.status(co) == 'suspended' then parked[#parked + 1] = co end
    end
end
_G.Wait = function() if coroutine.isyieldable() then coroutine.yield() end end

_G.exports = setmetatable({}, { __call = function() end, __index = function() return function() end end })
_G.PlayerId = function() return 1 end
_G.PlayerPedId = function() return 1 end
_G.GetPlayerServerId = function() return 1 end
_G.LocalPlayer = { state = {} }
_G.AddStateBagChangeHandler = function() end
_G.GetHashKey = function(v) return v end
_G.joaat = function(v) return v end
_G.GetEntityModel = function() return 'mp_m_freemode_01' end
_G.GetGameTimer = function() return 0 end
_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end

local calls = {}
local function rec(name) return function(...) calls[#calls + 1] = { name = name, args = { ... } } end end
_G.SetPedComponentVariation = rec('component')
_G.SetPedPropIndex = function() end
_G.ClearPedProp = function() end
_G.SetPedHairColor = rec('hair')
_G.SetPedHeadBlendData = rec('blend')
_G.SetPedHeadOverlay = rec('overlay')
_G.SetPedHeadOverlayColor = rec('overlayColor')
_G.GetNumHairColors = function() return 64 end
_G.GetPedHairRgbColor = function() return 0, 0, 0 end
_G.ClearPedDecorations = function() end
_G.AddPedDecorationFromHashes = function() end
_G.GetPedDrawableVariation = function() return 1 end
_G.GetPedTextureVariation = function() return 0 end
_G.GetNumberOfPedDrawableVariations = function() return 5 end
_G.GetNumberOfPedTextureVariations = function() return 5 end
_G.GetNumberOfPedPropDrawableVariations = function() return 0 end
_G.GetNumberOfPedPropTextureVariations = function() return 0 end

local savedSkin = { components = { ['2'] = { d = 1, t = 0 } }, hairColor = 9, hairHighlight = 11, head = { beard = 2, beardColor = 7 } }
_G.Kora = {
    callback = { trigger = function() return 'mp_m_freemode_01', savedSkin end },
    notify = { send = function() end },
}

dofile('config.lua')
-- These checks exercise the kora_target storefront path; the shipped default is 'textui'.
Config.interactionMode = 'target'
Config.testMode = true
Config.shops = {}
dofile('shared/components.lua')
_G.RegisterCommand = _G.RegisterCommand or function() end
_G.TriggerEvent = _G.TriggerEvent or function() end
dofile('client/client.lua')

H.equal(Config.loginColourReapply.enabled, true, 'login colour re-apply is on by default')
H.ok(#Config.loginColourReapply.delays > 0, 'default delays are set')

local function hairCalls()
    local n = 0
    for _, c in ipairs(calls) do if c.name == 'hair' then n = n + 1 end end
    return n
end

-- applySkin: the last hair tint comes after the head blend data.
QBClothing._testRuntime.applySkin(1, savedSkin, 'mp_m_freemode_01')
local lastBlend, lastHair
for i, c in ipairs(calls) do
    if c.name == 'blend' then lastBlend = i end
    if c.name == 'hair' then lastHair = i end
end
H.ok(lastBlend and lastHair and lastHair > lastBlend, 'hair tint is applied after SetPedHeadBlendData')
H.equal(calls[lastHair].args[2], 9, 'saved hair colour is applied')
H.equal(calls[lastHair].args[3], 11, 'saved hair highlight is applied')

-- Login: first apply, then the re-assert after the delays.
calls = {}
registeredNetEvents['QBCore:Client:OnPlayerLoaded']()
local afterApply = hairCalls()
H.ok(afterApply >= 1, 'login applies the saved hair colour')
resumeParked()
resumeParked()
H.ok(hairCalls() > afterApply, 'login re-asserts the hair colour after the delays')
local last
for _, c in ipairs(calls) do if c.name == 'hair' then last = c end end
H.equal(last.args[2], 9, 're-asserted colour is the saved one')

-- Disabled: applied once only.
Config.loginColourReapply.enabled = false
calls, parked = {}, {}
registeredNetEvents['QBCore:Client:OnPlayerLoaded']()
local once = hairCalls()
resumeParked()
resumeParked()
H.equal(hairCalls(), once, 'enabled=false applies the skin once only')

-- A newer login supersedes a pending re-assert.
Config.loginColourReapply.enabled = true
calls, parked = {}, {}
registeredNetEvents['QBCore:Client:OnPlayerLoaded']()
local first = parked[1]
registeredNetEvents['QBCore:Client:OnPlayerLoaded']()
local before = hairCalls()
coroutine.resume(first)
H.equal(hairCalls(), before, 'a superseded login does not re-assert')

H.finish()

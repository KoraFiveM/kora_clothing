-- Optional tattoo artist peds: off by default, spawned only near a tattoo shop,
-- "Get tattooed" opens the studio, faded while the studio is open, cleaned up.
local H = dofile('test/harness.lua')

local netEvents, stopHandlers, threads, requests = {}, {}, {}, {}
_G.RegisterNetEvent = function(name, fn) netEvents[name] = fn end
_G.AddEventHandler = function(name, fn) if name == 'onResourceStop' then stopHandlers[#stopHandlers + 1] = fn end end
_G.RegisterNUICallback = function() end
_G.CreateThread = function(fn) threads[#threads + 1] = fn end
_G.GetCurrentResourceName = function() return 'kora_clothing' end
_G.PlayerId = function() return 1 end
_G.GetPlayerServerId = function() return 1 end
_G.LocalPlayer = { state = {} }
_G.AddStateBagChangeHandler = function() end
local vec = {}
vec.__index = vec
vec.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vec) end
vec.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
_G.vector3 = function(x, y, z) return setmetatable({ x = x, y = y, z = z }, vec) end
_G.vector4 = function(x, y, z, w) return setmetatable({ x = x, y = y, z = z, w = w }, vec) end
_G.joaat = function(value) return value end
_G.GetGameTimer = function() return 0 end
_G.Wait = function() end

-- Player position, and a fake entity world.
local player = vector3(0.0, 0.0, 0.0)
_G.PlayerPedId = function() return 1 end
_G.GetEntityCoords = function() return player end
local world, nextHandle, alphaCalls, resets, targets, removedTargets, created = {}, 100, {}, {}, {}, {}, {}
_G.IsModelInCdimage = function() return true end
_G.RequestModel = function() end
_G.HasModelLoaded = function() return true end
_G.SetModelAsNoLongerNeeded = function() end
_G.RequestCollisionAtCoord = function() end
-- Ground is probed from 2.0 above the shop coords; here it is 0.5 below them.
_G.GetGroundZFor_3dCoord = function(x, y, z) return true, z - 2.5 end
_G.CreatePed = function(pedType, model, x, y, z, heading)
    nextHandle = nextHandle + 1
    world[nextHandle] = { model = model, x = x, y = y, z = z, heading = heading }
    created[#created + 1] = nextHandle
    return nextHandle
end
_G.DoesEntityExist = function(entity) return entity == 1 or world[entity] ~= nil end
_G.DeleteEntity = function(entity) world[entity] = nil end
_G.SetEntityInvincible = function(entity, value) world[entity].invincible = value end
_G.SetBlockingOfNonTemporaryEvents = function(entity, value) world[entity].blockEvents = value end
_G.FreezeEntityPosition = function(entity, value) if world[entity] then world[entity].frozen = value end end
_G.TaskStartScenarioInPlace = function(entity, scenario) world[entity].scenario = scenario end
_G.SetEntityAlpha = function(entity, alpha, skin) alphaCalls[#alphaCalls + 1] = { entity = entity, alpha = alpha, skin = skin } end
_G.ResetEntityAlpha = function(entity) resets[#resets + 1] = entity end
_G.exports = setmetatable({
    kora_target = {
        addEntity = function(_, entity, options, distance)
            targets[#targets + 1] = { entity = entity, options = options, distance = distance }
            return #targets
        end,
        removeEntity = function(_, entity, id) removedTargets[#removedTargets + 1] = { entity = entity, id = id } end,
        addPolyZone = function() end, addBoxZone = function() end,
    },
}, { __call = function() end })

-- Session plumbing for the studio fade.
_G.GetEntityModel = function() return 'mp_m_freemode_01' end
_G.SetNuiFocus = function() end
_G.SendNUIMessage = function() end
_G.Camera = { start = function() end, stop = function() end }
_G.QBTheme = { refresh = function() end }
_G.GetResourceState = function() return 'stopped' end
_G.IsRadarHidden = function() return false end
_G.DisplayRadar = function() end
_G.DisableAllControlActions = function() end
_G.EnableControlAction = function() end
_G.IsEntityDead = function() return false end
for _, name in ipairs({ 'GetNumberOfPedDrawableVariations', 'GetNumberOfPedTextureVariations', 'GetNumberOfPedPropDrawableVariations', 'GetNumberOfPedPropTextureVariations' }) do
    _G[name] = function() return 0 end
end
_G.GetPedDrawableVariation = function() return 0 end
_G.GetPedTextureVariation = function() return 0 end
_G.GetPedPropIndex = function() return -1 end
_G.GetPedPropTextureIndex = function() return 0 end
_G.SetPedHairColor = function() end
_G.GetNumHairColors = function() return 64 end
_G.ClearPedProp = function() end
_G.SetPedComponentVariation = function() end
_G.SetPedPropIndex = function() end
_G.ClearPedDecorations = function() end

local clerks = 0
_G.QB = {
    notify = { send = function() end },
    events = { trigger = function(name, mode, extra) requests[#requests + 1] = { name = name, mode = mode, extra = extra }; return true end },
    entities = { createScoped = function() clerks = clerks + 1 end },
    blips = { create = function() end, setInfo = function() end },
    zones = { poly = function() end, box = function() end },
    textui = { show = function() return 1 end, hide = function() end },
    keybind = { add = function() end },
}
_G.Kora = _G.QB

dofile('config.lua')
dofile('shared/components.lua')
Config.testMode = true
dofile('client/client.lua')
local runtime = QBClothing._testRuntime
local shopsThread = threads[#threads] -- the last CreateThread at load registers the shops

local tattooShops = {}
for index, shop in ipairs(Config.shops) do
    if shop.service == 'tattoo' then tattooShops[#tattooShops + 1] = index end
end
H.ok(#tattooShops >= 1, 'the default config has tattoo shops')
local first = Config.shops[tattooShops[1]]
local function standAt(coords) player = vector3(coords.x, coords.y, coords.z) end
local function liveCount() local n = 0 for _ in pairs(world) do n = n + 1 end return n end

-- Off by default: nothing spawns however close the player is.
H.equal(Config.tattoo.peds.enabled, false)
H.equal(Config.tattoo.peds.alpha, 0)
standAt(first.coords)
runtime.syncTattooPeds()
H.equal(#created, 0, 'no artist while disabled')

-- Enabled: spawns the artist near the shop, frozen and untouchable, with a target.
Config.tattoo.peds.enabled = true
runtime.syncTattooPeds()
H.equal(#created, 1, 'one artist near one shop')
local artist = world[created[1]]
H.equal(artist.model, first.ped, 'uses the shop ped model (u_m_y_tattoo_01 by default)')
H.equal(artist.model, 'u_m_y_tattoo_01')
H.equal(artist.x, first.coords.x)
H.equal(artist.heading, first.coords.w)
H.equal(artist.z, first.coords.z + 0.5, 'stands on the probed ground, middle 1.0 above it')
H.equal(artist.frozen, true)
H.equal(artist.invincible, true)
H.equal(artist.blockEvents, true)
H.equal(artist.scenario, nil, 'no scenario unless configured')
H.equal(#targets, 1)
H.equal(targets[1].options[1].label, 'Get tattooed')
runtime.syncTattooPeds()
H.equal(#created, 1, 'no duplicate on the next pass')

-- Selecting the target opens the studio for that shop; the zone path is unchanged.
targets[1].options[1].onSelect()
H.equal(requests[#requests].name, 'qbclothing:server:requestSession')
H.equal(requests[#requests].mode, 'shop')
H.equal(requests[#requests].extra.shopId, tattooShops[1])

-- Studio open: faded to Config alpha (locally); closing resets it.
netEvents['qbclothing:client:openSession']({ mode = 'shop', service = 'tattoo', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
H.equal(#alphaCalls, 1)
H.equal(alphaCalls[1].entity, created[1])
H.equal(alphaCalls[1].alpha, 0)
H.equal(alphaCalls[1].skin, false, 'not networked skin alpha')
netEvents['qbclothing:client:closeSession']({ ok = true })
H.equal(resets[#resets], created[1], 'alpha reset on close')

Config.tattoo.peds.alpha = 40
netEvents['qbclothing:client:openSession']({ mode = 'shop', service = 'tattoo', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
H.equal(alphaCalls[#alphaCalls].alpha, 40, 'configured alpha is used')
netEvents['qbclothing:client:closeSession']({ ok = true, cancelled = true })
H.equal(#resets, 2, 'cancel resets too')

-- A clothing shop session leaves the artist alone.
local before = #alphaCalls
netEvents['qbclothing:client:openSession']({ mode = 'shop', service = 'clothing', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
netEvents['qbclothing:client:closeSession']({ ok = true })
H.equal(#alphaCalls, before, 'only the tattoo studio fades the artist')

-- An artist that spawns while the studio is open is faded too.
Config.tattoo.peds.alpha = 0
netEvents['qbclothing:client:openSession']({ mode = 'shop', service = 'tattoo', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
player = vector3(5000.0, 5000.0, 0.0)
runtime.syncTattooPeds()
H.equal(liveCount(), 0, 'walking far away deletes the artist')
H.equal(removedTargets[#removedTargets].entity, created[1], 'its target is removed with it')
standAt(first.coords)
runtime.syncTattooPeds()
H.equal(alphaCalls[#alphaCalls].entity, created[#created], 'a respawn during the studio starts faded')
netEvents['qbclothing:client:closeSession']({ ok = true })

-- Per-shop overrides: scenario, model, position, and opting out.
for index in pairs(runtime.tattooPeds) do runtime.tattooPeds[index] = nil end
for handle in pairs(world) do world[handle] = nil end
first.tattooPed = { model = 'a_m_y_hipster_01', coords = vector4(first.coords.x + 1.0, first.coords.y, first.coords.z, 10.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' }
runtime.syncTattooPeds()
local override = world[created[#created]]
H.equal(override.model, 'a_m_y_hipster_01')
H.equal(override.x, first.coords.x + 1.0)
H.equal(override.scenario, 'WORLD_HUMAN_STAND_IMPATIENT')
first.tattooPed = false
for index in pairs(runtime.tattooPeds) do runtime.tattooPeds[index] = nil end
for handle in pairs(world) do world[handle] = nil end
local count = #created
runtime.syncTattooPeds()
H.equal(#created, count, 'tattooPed = false gives that shop no artist')
first.tattooPed = nil

-- Non-tattoo shops never get an artist.
for _, shop in ipairs(Config.shops) do
    if shop.service ~= 'tattoo' then standAt(shop.coords); break end
end
for index in pairs(runtime.tattooPeds) do runtime.tattooPeds[index] = nil end
for handle in pairs(world) do world[handle] = nil end
count = #created
runtime.syncTattooPeds()
H.equal(#created, count, 'no artist at a clothing or barber shop')

-- Turning the option off removes the artists; resource stop removes them too.
standAt(first.coords)
runtime.syncTattooPeds()
H.equal(liveCount(), 1)
Config.tattoo.peds.enabled = false
runtime.syncTattooPeds()
H.equal(liveCount(), 0, 'disabling removes live artists')
Config.tattoo.peds.enabled = true
runtime.syncTattooPeds()
H.equal(liveCount(), 1)
for _, handler in ipairs(stopHandlers) do handler('some_other_resource') end
H.equal(liveCount(), 1, 'another resource stopping leaves the artist')
for _, handler in ipairs(stopHandlers) do handler('kora_clothing') end
H.equal(liveCount(), 0, 'resource stop deletes the artists')

-- With the artist on, the decorative clerk is not also spawned at tattoo shops.
local function startShops()
    clerks = 0
    shopsThread()
    return clerks
end
Config.shopPeds = true
Config.tattoo.peds.enabled = false
local withClerks = startShops()
Config.tattoo.peds.enabled = true
local withoutTattooClerks = startShops()
H.equal(withClerks - withoutTattooClerks, #tattooShops, 'tattoo shops lose the clerk while artists are on')

H.finish()

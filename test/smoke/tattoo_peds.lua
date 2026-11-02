-- Tattoo artist peds (Config.tattoo.peds): on by default, one kora_lib zone per
-- tattoo shop spawns the artist on enter and deletes it on exit (no polling),
-- the artist stands on the floor, "Get tattooed" opens the studio, the shop's
-- storefront zone is down while the artist is there and back when it is gone,
-- the artist is faded while the studio is open, config changes rebuild it.
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
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.joaat = function(value) return value end
_G.GetGameTimer = function() return 0 end
_G.Wait = function() end
_G.PlayerPedId = function() return 1 end
_G.GetEntityCoords = function() return vector3(0.0, 0.0, 0.0) end

-- Runs the threads queued since `threads` was last cleared (a spawn streams its
-- model in one). Session threads are never run here: Wait is a no-op, so their
-- watch loops would spin.
local function runThreads()
    local queued = threads
    threads = {}
    for _, fn in ipairs(queued) do fn() end
end

-- A fake entity world behind Kora.entities.
local world, nextHandle, created, alphaCalls, resets = {}, 100, {}, {}, {}
local modelMissing = false
_G.DoesEntityExist = function(entity) return entity == 1 or world[entity] ~= nil end
_G.DeleteEntity = function(entity) world[entity] = nil end
_G.FreezeEntityPosition = function(entity, value) if world[entity] then world[entity].frozen = value end end
_G.TaskStartScenarioInPlace = function(entity, scenario) world[entity].scenario = scenario end
_G.SetEntityAlpha = function(entity, alpha, skin) alphaCalls[#alphaCalls + 1] = { entity = entity, alpha = alpha, skin = skin } end
_G.ResetEntityAlpha = function(entity) resets[#resets + 1] = entity end

-- kora_target: zone ids, entity targets and removals.
local zones, removedZones, targets, removedTargets, nextZone = {}, {}, {}, {}, 0
local function addZone(_, opts)
    nextZone = nextZone + 1
    zones[nextZone] = opts
    return nextZone
end
_G.exports = setmetatable({
    kora_target = {
        addPolyZone = addZone, addBoxZone = addZone,
        removeZone = function(_, id) removedZones[#removedZones + 1] = id; zones[id] = nil; return true end,
        addEntity = function(_, entity, options, distance)
            targets[#targets + 1] = { entity = entity, options = options, distance = distance }
            return #targets
        end,
        removeEntity = function(_, entity, id) removedTargets[#removedTargets + 1] = { entity = entity, id = id } end,
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

local spheres, clerks, changeHandlers = {}, 0, {}
_G.Kora = {
    notify = { send = function() end },
    events = { trigger = function(name, mode, extra) requests[#requests + 1] = { name = name, mode = mode, extra = extra }; return true end },
    entities = {
        createScoped = function() clerks = clerks + 1 end,
        create = function(model, coords, options)
            if modelMissing then return false, 'model not found' end
            nextHandle = nextHandle + 1
            world[nextHandle] = { model = model, x = coords.x, y = coords.y, z = coords.z, heading = coords.heading, preset = options and options.preset }
            created[#created + 1] = nextHandle
            return nextHandle
        end,
        remove = function(entity) local existed = world[entity] ~= nil; world[entity] = nil; return existed end,
    },
    zones = {
        poly = function() end, box = function() end,
        sphere = function(opts)
            local sphere = { opts = opts, removed = false }
            sphere.remove = function() sphere.removed = true end
            spheres[#spheres + 1] = sphere
            return sphere
        end,
    },
    blips = { create = function() end, setInfo = function() end },
    textui = { show = function() return 1 end, hide = function() end },
    keybind = { add = function() end },
}

dofile('config.lua')
dofile('shared/components.lua')
-- Only onChange is needed by the client; config.lua above used its plain defaults.
Kora.config = { onChange = function(path, fn) changeHandlers[path] = fn end }
Config.testMode = true
_G.RegisterCommand = _G.RegisterCommand or function() end
_G.TriggerEvent = _G.TriggerEvent or function() end
dofile('client/client.lua')
local runtime = QBClothing._testRuntime
local shopsThread = threads[#threads] -- the last CreateThread at load registers the shops
threads = {}

local tattooShops = {}
for index, shop in ipairs(Config.shops) do
    if shop.service == 'tattoo' then tattooShops[#tattooShops + 1] = index end
end
H.ok(#tattooShops >= 1, 'the default config has tattoo shops')
local firstIndex = tattooShops[1]
local first = Config.shops[firstIndex]

local function liveSpheres()
    local list = {}
    for _, sphere in ipairs(spheres) do if not sphere.removed then list[#list + 1] = sphere end end
    return list
end
local function sphereFor(shop)
    for _, sphere in ipairs(liveSpheres()) do
        if sphere.opts.coords.x == shop.coords.x and sphere.opts.coords.y == shop.coords.y then return sphere end
    end
end
local function liveCount() local n = 0 for _ in pairs(world) do n = n + 1 end return n end
local function storefrontOf(index) return runtime.storefrontZones[index] end
local function enter(shop) threads = {}; sphereFor(shop).opts.onEnter(); runThreads() end
local function exit(shop) sphereFor(shop).opts.onExit() end

-- Defaults: on, invisible in the studio, a prop-free idle scenario.
H.equal(Config.tattoo.peds.enabled, true, 'artists are on by default')
H.equal(Config.tattoo.peds.alpha, 0)
H.equal(Config.tattoo.peds.scopeRadius, 40.0)
H.equal(Config.tattoo.peds.model, 'u_m_y_tattoo_01')
H.equal(Config.tattoo.peds.scenario, 'WORLD_HUMAN_STAND_IMPATIENT')
for _, key in ipairs({ 'enabled', 'scopeRadius', 'model', 'scenario' }) do
    H.ok(changeHandlers['tattoo.peds.' .. key], 'config changes to ' .. key .. ' rebuild the artists')
end

-- Start: every shop has its storefront zone, every tattoo shop one artist scope,
-- and nothing is spawned until the player walks in.
shopsThread()
H.equal(#liveSpheres(), #tattooShops, 'one scope per tattoo shop, none elsewhere')
for index in ipairs(Config.shops) do H.ok(storefrontOf(index), 'storefront zone registered for shop ' .. index) end
local sphere = sphereFor(first)
H.equal(sphere.opts.radius, 40.0)
H.equal(sphere.opts.coords.z, first.coords.z)
H.equal(#created, 0, 'nothing spawned before the player is near')

-- Entering the scope spawns the artist standing on the floor with the target,
-- and takes that shop's storefront zone down (no zone sprite / prompt next to it).
local storefrontId = storefrontOf(firstIndex)
enter(first)
H.equal(#created, 1, 'one artist near one shop')
local artistHandle = created[1]
local artist = world[artistHandle]
H.equal(artist.model, 'u_m_y_tattoo_01', 'uses the shop ped model')
H.equal(artist.x, first.coords.x)
H.equal(artist.y, first.coords.y)
H.equal(artist.z, first.coords.z - 1.0, 'stands on the floor below the standing-player coords')
H.equal(artist.heading, first.coords.w)
H.equal(artist.preset, 'static', 'frozen, invincible, ignores events')
H.equal(artist.scenario, 'WORLD_HUMAN_STAND_IMPATIENT')
H.equal(#targets, 1)
H.equal(targets[1].entity, artistHandle)
H.equal(targets[1].options[1].label, 'Get tattooed')
H.equal(storefrontOf(firstIndex), nil, 'storefront zone is down while the artist is there')
H.equal(removedZones[#removedZones], storefrontId)
for _, index in ipairs(tattooShops) do
    if index ~= firstIndex then H.ok(storefrontOf(index), 'other shops keep their storefront') end
end
threads = {}; sphere.opts.onEnter(); runThreads()
H.equal(#created, 1, 'no duplicate on re-enter')

-- Selecting the target opens the studio for that shop.
targets[1].options[1].onSelect()
H.equal(requests[#requests].name, 'qbclothing:server:requestSession')
H.equal(requests[#requests].mode, 'shop')
H.equal(requests[#requests].extra.shopId, firstIndex)

-- Studio open: faded to Config alpha (locally); closing resets it.
netEvents['qbclothing:client:openSession']({ mode = 'shop', service = 'tattoo', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
H.equal(#alphaCalls, 1)
H.equal(alphaCalls[1].entity, artistHandle)
H.equal(alphaCalls[1].alpha, 0)
H.equal(alphaCalls[1].skin, false, 'not networked skin alpha')
netEvents['qbclothing:client:closeSession']({ ok = true })
H.equal(resets[#resets], artistHandle, 'alpha reset on close')

Config.tattoo.peds.alpha = 40
netEvents['qbclothing:client:openSession']({ mode = 'shop', service = 'tattoo', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
H.equal(alphaCalls[#alphaCalls].alpha, 40, 'configured alpha is used')
netEvents['qbclothing:client:closeSession']({ ok = true, cancelled = true })
H.equal(#resets, 2, 'cancel resets too')
Config.tattoo.peds.alpha = 0

-- A clothing shop session leaves the artist alone.
local before = #alphaCalls
netEvents['qbclothing:client:openSession']({ mode = 'shop', service = 'clothing', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
netEvents['qbclothing:client:closeSession']({ ok = true })
H.equal(#alphaCalls, before, 'only the tattoo studio fades the artist')

-- Leaving deletes the artist and its target and brings the storefront back.
exit(first)
H.equal(liveCount(), 0, 'walking away deletes the artist')
H.equal(removedTargets[#removedTargets].entity, artistHandle, 'its target is removed with it')
H.ok(storefrontOf(firstIndex), 'storefront zone is back without the artist')
H.equal(zones[storefrontOf(firstIndex)].spriteCoords.x, first.coords.x, 'the same storefront is re-registered')

-- An artist that spawns while the studio is open starts faded.
netEvents['qbclothing:client:openSession']({ mode = 'shop', service = 'tattoo', model = 'mp_m_freemode_01', skin = {}, tattoos = {} })
enter(first)
H.equal(alphaCalls[#alphaCalls].entity, created[#created], 'a respawn during the studio starts faded')
netEvents['qbclothing:client:closeSession']({ ok = true })
exit(first)

-- Leaving while the model streams: the late ped is deleted, the storefront stays.
threads = {}
sphereFor(first).opts.onEnter()
exit(first)
local targetCount = #targets
runThreads()
H.equal(liveCount(), 0, 'a ped that finished after the player left is deleted')
H.equal(#targets, targetCount, 'and gets no target')
H.ok(storefrontOf(firstIndex), 'storefront stays up')

-- A model that cannot be spawned leaves the storefront zone in place.
modelMissing = true
enter(first)
H.equal(liveCount(), 0)
H.ok(storefrontOf(firstIndex), 'no artist, so the shop zone still opens the studio')
exit(first)
modelMissing = false

-- Turning the option off (live, or by kora_lib's snapshot after start) removes
-- every artist scope and its ped and brings the storefront back; on rebuilds them.
enter(first)
H.equal(liveCount(), 1)
Config.tattoo.peds.enabled = false
changeHandlers['tattoo.peds.enabled'](false, true)
H.equal(liveCount(), 0, 'disabling removes live artists')
H.equal(#liveSpheres(), 0, 'and their scopes')
H.ok(storefrontOf(firstIndex), 'storefront back when artists are off')
Config.tattoo.peds.enabled = true
changeHandlers['tattoo.peds.enabled'](true, false)
H.equal(#liveSpheres(), #tattooShops, 'enabling registers the scopes again')

-- Per-shop overrides: scenario, model, position, and opting out.
first.tattooPed = { model = 'a_m_y_hipster_01', coords = vector4(first.coords.x + 1.0, first.coords.y, first.coords.z, 10.0), scenario = '' }
changeHandlers['tattoo.peds.model']()
local overrideSphere
for _, s in ipairs(liveSpheres()) do if s.opts.coords.x == first.coords.x + 1.0 then overrideSphere = s end end
H.ok(overrideSphere, 'the scope follows the override position')
threads = {}; overrideSphere.opts.onEnter(); runThreads()
local override = world[created[#created]]
H.equal(override.model, 'a_m_y_hipster_01')
H.equal(override.x, first.coords.x + 1.0)
H.equal(override.heading, 10.0)
H.equal(override.scenario, nil, "scenario = '' leaves the artist idle")
overrideSphere.opts.onExit()
first.tattooPed = false
changeHandlers['tattoo.peds.model']()
H.equal(#liveSpheres(), #tattooShops - 1, 'tattooPed = false gives that shop no artist')
first.tattooPed = nil
changeHandlers['tattoo.peds.model']()

-- Text prompt mode: the artist is decoration only, the prompt zone opens the shop.
Config.interactionMode = 'textui'
targetCount = #targets
enter(first)
H.equal(liveCount(), 1)
H.equal(#targets, targetCount, 'no target option in textui mode')
exit(first)
Config.interactionMode = 'target'

-- Resource stop deletes the artists; another resource stopping does not.
enter(first)
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

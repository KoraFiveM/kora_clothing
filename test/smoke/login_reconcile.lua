-- Regression coverage for the state-bag reconcile path added alongside
-- qbhud's (client/bridge/qbcore.lua): `ensure qbclothing` mid-session must
-- re-apply the player's saved skin WITHOUT waiting for
-- QBCore:Client:OnPlayerLoaded to fire again -- that legacy event does not
-- re-fire on a resource restart, only on an actual fresh login. Proves the
-- reconcile fires purely off LocalPlayer.state['qbcore:loggedIn'] already
-- being true at chunk load.
local H = dofile('test/harness.lua')

_G.GetCurrentResourceName = function() return 'qbclothing' end
_G.AddEventHandler = function() end

local registeredNetEvents = {}
_G.RegisterNetEvent = function(name, cb) registeredNetEvents[name] = cb end
_G.RegisterNUICallback = function() end

-- Every CreateThread this test's code paths reach (the reconcile's own
-- callback-trigger thread, and the shop-ped spawn loop at chunk load -- see
-- Config.shops override below) never calls Wait, so running the body
-- synchronously is enough; no coroutine plumbing needed.
_G.CreateThread = function(fn) fn() end

_G.exports = setmetatable({}, {
    __call = function() end,
    __index = function() return function() end end,
})

_G.PlayerId = function() return 1 end
_G.PlayerPedId = function() return 1 end
_G.GetPlayerServerId = function() return 1 end

-- Simulates `ensure qbclothing` mid-session: the server-owned login state
-- bag is ALREADY true by the time this chunk loads, and nothing will flip it
-- again (no fresh login is happening).
_G.LocalPlayer = { state = { ['qbcore:loggedIn'] = true } }

local stateBagHandlers = {}
_G.AddStateBagChangeHandler = function(key, bag, cb)
    stateBagHandlers[#stateBagHandlers + 1] = { key = key, bag = bag, cb = cb }
end

-- applyModel natives: keep the ped already on the target model so it skips
-- straight to applySkin (same simplification apply_skin_bounds.lua uses).
_G.GetHashKey = function(v) return v end
_G.GetEntityModel = function() return 'mp_m_freemode_01' end
_G.RequestModel = function() end
_G.HasModelLoaded = function() return true end
_G.SetPlayerModel = function() end
_G.SetModelAsNoLongerNeeded = function() end
_G.SetPedDefaultComponentVariation = function() end
_G.GetGameTimer = function() return 0 end
_G.Wait = function() end
_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end

local componentCalls = {}
_G.SetPedComponentVariation = function(_, id, drawable, texture)
    componentCalls[#componentCalls + 1] = { id = id, drawable = drawable, texture = texture }
end
_G.SetPedPropIndex = function() end
_G.ClearPedProp = function() end
_G.ClearPedDecorations = function() end
_G.AddPedDecorationFromHashes = function() end
_G.GetNumberOfPedDrawableVariations = function() return 5 end
_G.GetNumberOfPedTextureVariations = function() return 5 end
_G.GetNumberOfPedPropDrawableVariations = function() return 0 end
_G.GetNumberOfPedPropTextureVariations = function() return 0 end

local getSkinCalls = 0
_G.QB = {
    callback = {
        trigger = function(name)
            if name == 'qb-clothing:server:getSkin' then
                getSkinCalls = getSkinCalls + 1
                return 'mp_m_freemode_01', { components = { ['0'] = { d = 1, t = 1 } } }
            end
        end,
    },
    notify = { send = function() end },
}

dofile('config.lua')
Config.testMode = true
-- Emptied so the unrelated chunk-load shop-ped spawn thread (QB.entities.
-- create/exports.qbtarget) is a no-op -- irrelevant to this test and not
-- worth mocking out.
Config.shops = {}
dofile('shared/components.lua')
dofile('client/client.lua')

H.ok(registeredNetEvents['QBCore:Client:OnPlayerLoaded'] ~= nil,
    'the legacy OnPlayerLoaded handler must still be registered (fresh-login path stays intact)')

local loginHandler
for _, h in ipairs(stateBagHandlers) do
    if h.key == 'qbcore:loggedIn' then loginHandler = h end
end
H.ok(loginHandler ~= nil, 'client.lua must watch the qbcore:loggedIn state bag')
H.equal(loginHandler.bag, 'player:1', 'the handler must be scoped to the local player state bag')

H.equal(getSkinCalls, 1, 'the saved skin must be fetched once purely from the already-true state bag at load')
H.equal(#componentCalls, 1, 'the saved skin must be applied to the ped')
H.equal(componentCalls[1].id, 0, 'the fetched skin (component 0) was applied')
H.equal(componentCalls[1].drawable, 1, 'the fetched skin drawable was applied unchanged (in-range)')

-- The legacy event handler is still wired and, if fired, applies again (a
-- real fresh login fires both paths -- the generation guard in client.lua
-- just prevents a stale in-flight call from clobbering a newer one, it does
-- not prevent two genuinely sequential logins from each re-applying).
registeredNetEvents['QBCore:Client:OnPlayerLoaded']()
H.equal(getSkinCalls, 2, 'firing the legacy event still re-applies (it is an ADDITIONAL path, not a replacement)')

H.finish()

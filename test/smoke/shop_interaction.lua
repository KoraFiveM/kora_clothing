-- Shop registration: target hint mapping (Config.showTargetHints), sprite
-- anchoring, and the optional text prompt mode (Config.interactionMode).
local H = dofile('test/harness.lua')

_G.vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.GetCurrentResourceName = function() return 'kora_clothing' end
_G.AddEventHandler = function() end
_G.RegisterNetEvent = function() end
_G.RegisterNUICallback = function() end
_G.PlayerId = function() return 1 end
_G.GetPlayerServerId = function() return 1 end
_G.LocalPlayer = { state = {} }
_G.AddStateBagChangeHandler = function() end

local polyZones, boxZones, requests = {}, {}, {}
local textZones, keybinds, prompts, hidden = {}, {}, {}, {}
_G.exports = setmetatable({
    kora_target = {
        addPolyZone = function(_, opts) polyZones[#polyZones + 1] = opts end,
        addBoxZone = function(_, opts) boxZones[#boxZones + 1] = opts end,
    },
}, { __call = function() end })

_G.QB = {
    events = { trigger = function(name, mode, extra) requests[#requests + 1] = { name = name, mode = mode, extra = extra }; return true end },
    entities = { createScoped = function() end },
    blips = { create = function() end, setInfo = function() end },
    zones = {
        poly = function(opts) textZones[#textZones + 1] = opts end,
        box = function(opts) textZones[#textZones + 1] = opts end,
    },
    textui = {
        show = function(text, opts) prompts[#prompts + 1] = { text = text, key = opts.key }; return #prompts end,
        hide = function(handle) hidden[#hidden + 1] = handle end,
    },
    keybind = { add = function(opts) keybinds[opts.name] = opts end },
}
local startThread
_G.CreateThread = function(fn) startThread = fn end

dofile('config.lua')
dofile('shared/components.lua')

local function load(settings)
    polyZones, boxZones, requests, textZones, keybinds, prompts, hidden = {}, {}, {}, {}, {}, {}, {}
    Config.showTargetHints, Config.interactionMode = settings.hints, settings.mode
    dofile('client/client.lua')
    startThread() -- the last CreateThread in client.lua registers the shops
end

local function eachZone(fn)
    for _, opts in ipairs(polyZones) do fn(opts) end
    for _, opts in ipairs(boxZones) do fn(opts) end
end

-- Defaults change nothing: target zones, hint left to kora_target.
H.equal(Config.interactionMode, 'target')
H.equal(Config.showTargetHints, nil)
load({ mode = 'target' })
H.equal(#polyZones + #boxZones, #Config.shops, 'one target zone per shop')
eachZone(function(opts) H.equal(opts.drawSprite, nil, 'nil follows kora_target (nothing passed)') end)

-- Every zone anchors its sprite on the shop's interaction point, not on a
-- polygon centroid that can sit inside a wall.
local shopCoords = Config.shops[1].coords
H.equal(polyZones[1].spriteCoords.x, shopCoords.x)
H.equal(polyZones[1].spriteCoords.y, shopCoords.y)
eachZone(function(opts) H.ok(opts.spriteCoords ~= nil, 'zones carry spriteCoords') end)

load({ mode = 'target', hints = true })
eachZone(function(opts) H.equal(opts.drawSprite, true, 'true forces the icon on') end)
load({ mode = 'target', hints = false })
eachZone(function(opts) H.equal(opts.drawSprite, false, 'false forces the icon off') end)
-- Box zones are centred on, and sprite-anchored to, the shop coords.
H.equal(boxZones[1].spriteCoords.x, boxZones[1].coords.x)

-- Text prompt mode: no target zones, a prompt on enter, E opens the shop.
load({ mode = 'textui' })
H.equal(#polyZones + #boxZones, 0, 'textui mode registers no target zones')
H.equal(#textZones, #Config.shops, 'one prompt zone per shop')
H.ok(keybinds.kora_clothing_open_shop ~= nil, 'E is bound once')
H.equal(keybinds.kora_clothing_open_shop.defaultKey, 'E')

keybinds.kora_clothing_open_shop.onPressed()
H.equal(#requests, 0, 'E outside a shop zone does nothing')

textZones[2].onEnter()
H.equal(prompts[#prompts].text, 'Open ' .. Config.shops[2].label)
H.equal(prompts[#prompts].key, 'E')
keybinds.kora_clothing_open_shop.onPressed()
H.equal(requests[#requests].name, 'qbclothing:server:requestSession')
H.equal(requests[#requests].extra.shopId, 2, 'E opens the shop whose zone the player is in')
H.equal(#hidden, 1, 'the prompt is hidden while the menu opens')
textZones[2].onExit()
keybinds.kora_clothing_open_shop.onPressed()
H.equal(#requests, 1, 'leaving the zone ends the E binding')

H.finish()

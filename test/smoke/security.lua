-- Source-contract coverage for security/UX boundaries that need an FXServer
-- to exercise at runtime -- these assertions inspect the public transport
-- shape instead of pretending a plain Lua process can emulate Cfx natives.
-- Same convention as qbinventory/test/smoke/security.lua.
local H = dofile('test/harness.lua')

local function read(path)
    local file = assert(io.open(path, 'r'))
    local source = file:read('*a')
    file:close()
    return source
end

local server = read('server/server.lua')
local persistence = read('server/persistence.lua')
local client = read('client/client.lua')
local camera = read('client/camera.lua')
local manifest = read('fxmanifest.lua')
local config = read('config.lua')
local shared = read('shared/components.lua')

-- No stray backtick hash-literal syntax (a CFX-only Lua extension) anywhere in
-- the resource -- a real occurrence silently breaks stock lua/luac-based
-- tooling like this smoke suite (see qbcore's own gotcha notes). Every
-- backtick present is inside an ordinary quoted SQL identifier string or a
-- comment, never bare source syntax.
for _, path in ipairs({ 'fxmanifest.lua', 'config.lua', 'shared/components.lua', 'server/persistence.lua', 'server/server.lua', 'client/client.lua', 'client/camera.lua' }) do
    local source = read(path)
    for line in source:gmatch('[^\n]*') do
        local stripped = line:gsub("%-%-.*$", ''):gsub("'[^']*'", ''):gsub('"[^"]*"', '')
        H.ok(not stripped:find('`', 1, true), ('%s has no bare backtick literal'):format(path))
    end
end

-- Session state is the sole authority for bucket restore and mandatory-mode
-- enforcement -- never trust client-submitted session identity.
H.ok(server:find('local sessions = {}', 1, true), 'server keeps its own session table')
H.ok(server:find("QB.events.register('qbclothing:server:requestSession'", 1, true), 'session open is routed through qblib\'s tokenised events gateway, not a raw guessable RegisterNetEvent')
H.ok(server:find("if sessions[src] then return end", 1, true), 'duplicate session requests are rejected')
H.ok(server:find('local session = sessions[src]', 1, true), 'confirm/cancel/delete look up session server-side')
H.ok(server:find('if not session or session.mandatory then return end', 1, true), 'mandatory first-character sessions cannot be cancelled')

-- Routing-bucket isolation must go through the qb-core compat export (keeps
-- QBCore.Functions.GetPlayersInBucket accurate for other legacy consumers),
-- never the raw native directly, and must always restore on every exit path.
H.ok(server:find("exports['qb-core']:SetPlayerBucket(src, bucket)", 1, true), 'entering the fitting room uses the qb-core bucket export')
H.ok(server:find('local function leaveFittingRoom(src, previousBucket)', 1, true), 'bucket restore is a single named function')
H.ok(server:find('leaveFittingRoom(src, session.previousBucket)', 1, true), 'confirm restores the prior bucket')
H.ok(server:find('pcall(leaveFittingRoom, src, session.previousBucket)', 1, true), 'a resource stop still restores every open session\'s bucket')

-- Shop pricing must be recomputed server-side from a DB re-read, never taken
-- from the client or from a session-open-time cache.
H.ok(server:find('local before = dbGetSkin(session.citizenid)', 1, true), 'price diff re-reads the saved skin at confirm time')
H.ok(server:find('local price = priceDiff(', 1, true), 'purchase price is computed server-side')
H.ok(server:find("exports.qbcore:removeMoney(src, Config.shop.currency, price, 'qbclothing-purchase')", 1, true), 'purchase takes server-side payment')
H.ok(not server:find('payload.price', 1, true), 'server never trusts a client-submitted price')

-- The free mandatory first-fitting must be usable exactly once per citizen --
-- otherwise a modified client could repeatedly request 'firstCharacter' mode
-- to dress for free forever. Pricing must apply to every OTHER mode too
-- (wardrobe shares the same live editor as shop), not just 'shop'.
H.ok(server:find("if mode == 'firstCharacter' and saved then return end", 1, true), 'firstCharacter cannot be replayed once a skin is already saved')
H.ok(server:find('if not nearShop(src, shop) then return end', 1, true), 'shop sessions require server-measured proximity')
H.ok(server:find('if not session.free and session.mode ~= \'firstCharacter\' and before and not ownedOutfitMatch(session.citizenid, model, newSkin) then', 1, true), 'configured free shops bypass pricing while paid sessions remain server-priced')
H.ok(server:find('local beforeSkin = sanitiseSkin((before and before.skin) or {}, model)', 1, true), 'the saved baseline is sanitised before pricing and persistence')
H.ok(server:find('return ok and added == true', 1, true), "boxing an outfit checks addItem's actual return value, not just that the export call didn't throw")
H.ok(server:find('if wantsBox then', 1, true) and server:find("equipped it directly instead", 1, true), 'a failed box falls back to a direct equip and tells the player, instead of silently losing a paid purchase')

-- Re-wearing an outfit you already saved shouldn't be priced again just
-- because it differs from whatever's currently equipped -- you already paid
-- for those pieces once. Must compare actual content (model + every
-- component/prop), not merely "you clicked Wear", so manually recreating an
-- owned look by hand is free too, and it must stay scoped to this citizen's
-- own playeroutfits rows (never another player's).
H.ok(server:find('local function skinsMatch(a, b)', 1, true), 'skin content equality is a dedicated comparison, not inferred from price')
H.ok(server:find('local function ownedOutfitMatch(citizenid, model, skin)', 1, true), 'ownership check is a named, reusable function')
H.ok(server:find('for _, row in ipairs(dbListOutfitSkins(citizenid)) do', 1, true), 'ownership check is scoped to the citizen\'s own saved outfits')
H.ok(server:find('not ownedOutfitMatch(session.citizenid, model, newSkin)', 1, true), 'pricing is skipped when the confirmed look matches an already-owned outfit')

-- Config.clothingAsItem: off by default; when on, the item is registered
-- with qbcore/qbinventory rather than assumed to already exist, purchases
-- still go through the same payment path as a direct equip, the item is
-- reusable (not consumed) so it behaves like a real wardrobe piece, and the
-- live try-on preview is reverted (never silently kept as "worn") once it's
-- actually boxed instead of equipped.
H.ok(config:find('Config.clothingAsItem = false', 1, true), 'clothing-as-item defaults off')
H.ok(server:find("exports.qbcore:registerShared('items', Config.clothingItem.name,", 1, true), 'the outfit item is registered with qbcore, not assumed to pre-exist')
H.ok(server:find("exports.qbinventory:createUseable(Config.clothingItem.name, equipFromItem)", 1, true), 'the outfit item registers a qbinventory use handler')
H.ok(server:find('local function equipFromItem(src, item)', 1, true) and server:find('return false\nend', 1, true), 'using an outfit item does not consume it')
H.ok(server:find('local wantsBox = not session.free and session.mode ~= ' .. "'firstCharacter'" .. ' and Config.clothingAsItem', 1, true), 'free configured sessions never produce free inventory outfit items')
H.ok(server:find('revertTo = boxed and { model = beforeModel, skin = beforeSkin } or nil', 1, true), 'a boxed purchase reverts the live try-on preview instead of leaving it worn')
H.ok(client:find("RegisterNetEvent('qbclothing:client:wearItem'", 1, true), 'client applies an equipped item on use')
H.ok(client:find('if activeSession then return end', 1, true), 'wearing an item is ignored while a fitting-room session is open')

-- Appearance is clamped server-side even though the true per-model cap can
-- only be known client-side.
H.ok(server:find('local function sanitiseSkin(rawSkin, model)', 1, true), 'submitted skin data is sanitised against the active model before persistence')
H.ok(server:find('local function clampIndex(value)', 1, true), 'drawable/texture indices are clamped')

-- Specialist shop policy is server-authoritative: a client may select only a
-- configured shop id, and mergeServiceSkin keeps every non-service field.
H.ok(config:find('Config.services = {', 1, true), 'service policy is configurable independently of locations')
H.ok(config:find("service = 'tattoo'", 1, true) and config:find("service = 'barber'", 1, true) and config:find("service = 'hairdresser'", 1, true), 'separate specialist shop locations are configured')
H.ok(config:find('coords = vector4(127.02, -223.29, 53.56, 70.0)', 1, true), 'the original clothing clerk is lowered by one metre')
H.ok(server:find("shopIndex = tonumber(type(extra) == 'table' and extra.shopId or extra)", 1, true), 'new options-table and legacy numeric shop opens share server validation')
H.ok(server:find('local function mergeServiceSkin(before, requested, service, model)', 1, true), 'specialist sessions merge only permitted appearance fields')
H.ok(server:find('if not serviceAllowsModel(service, model) then', 1, true), 'barber and hairdresser model restrictions are checked server-side')
H.ok(server:find('local function tattooPriceDiff(previousSkin, newSkin, model)', 1, true), 'new tattoos are individually priced server-side')
H.ok(server:find('Shared.tattooById(model, id)', 1, true), 'tattoos are validated against the configured model catalogue')
H.ok(client:find("RegisterNUICallback('qbclothing:nui:setTattoos'", 1, true), 'the NUI can preview tattoo selections')
H.ok(client:find('ClearPedDecorations(ped)', 1, true) and client:find('AddPedDecorationFromHashes', 1, true), 'tattoo decorations are reapplied to live peds')

-- A tattoo session bares whatever the catalogue needs to actually be seen,
-- and barber/hairdresser remove hat/mask so the hair being edited is visible
-- -- both temporary, captured and restored around the session, never sent to
-- the server or persisted.
H.ok(config:find('Config.tattooStrip = {', 1, true), 'tattoo strip variations are configurable per gender')
H.ok(client:find('local function applyTemporaryStrip(ped, service, model)', 1, true), 'a strip/hat-removal override is applied when a specialist session opens')
H.ok(client:find("local strip = Config.tattooStrip[Shared.modelGender(model)]", 1, true), 'the tattoo strip is resolved from config, not hardcoded per call site')
H.ok(client:find("service == 'barber' or service == 'hairdresser'", 1, true), 'barber and hairdresser both strip hat/mask, not just one')
H.ok(client:find('local function restoreTemporaryOverride(ped)', 1, true), 'the strip/removal is reversible')
H.ok(client:find('applyTemporaryStrip(ped, activeSession.service, currentModelName(ped))', 1, true), 'the override is applied only after the real skin is on the ped')
H.ok(client:find('restoreTemporaryOverride(PlayerPedId())', 1, true), 'closing the session restores whatever was temporarily overridden')
H.ok(client:find('temporaryOverride = nil\n            applyModel(result.revertTo.model, result.revertTo.skin)', 1, true),
    'a boxed-item close reapplies the full pre-session skin instead of double-restoring')

-- Real qb-clothing / qb-multicharacter wire-protocol compat.
H.ok(server:find("QB.callback.register('qb-clothing:server:getSkin'", 1, true), 'real qb-clothing getSkin callback is implemented')
H.ok(server:find('return saved.model, sanitiseSkin(saved.skin, saved.model)', 1, true),
    'the spawn-time getSkin callback sanitises the saved skin like every other read path -- ' ..
    'it used to return the raw DB blob straight to SetPedComponentVariation/SetPedPropIndex')
H.ok(server:find("QB.callback.register('qb-multicharacter:server:getSkin'", 1, true), 'qbmultichar character-select preview callback is overridden')
H.ok(server:find('exports.qbcore:ownsCharacter(src, citizenid)', 1, true), 'character preview appearance is ownership checked before reading the skin')
H.ok(server:find('previewCache[src]', 1, true), 'selection-session appearance reads are cached per source')
H.ok(server:find("AddStateBagChangeHandler('qbmultichar:mode'", 1, true), 'appearance cache clears when the cinematic selection session ends')
H.ok(server:find("rateLimit = { max = 20, window = 10000 }", 1, true), 'character preview appearance reads are rate limited')
H.ok(server:find('local skin = sanitiseSkin(saved.skin, saved.model)', 1, true), 'character preview appearance is sanitised before it reaches a ped')
H.ok(client:find("RegisterNetEvent('qb-clothing:client:CreateFirstCharacter'", 1, true), 'real qb-clothing CreateFirstCharacter event is implemented')
H.ok(client:find("RegisterNetEvent('qb-clothing:client:openMenu'", 1, true), 'real qb-clothing openMenu event is implemented')
H.ok(client:find("RegisterNetEvent('qb-clothing:client:openOutfitMenu'", 1, true), 'real qb-clothing openOutfitMenu event is implemented')
H.ok(client:find("RegisterNetEvent('qbclothing:client:openNearestShop'", 1, true), 'admin integrations can request the nearest configured service shop')
H.ok(client:find("RegisterNetEvent('qbclothing:client:openAdminSession'", 1, true), 'admin integrations use a dedicated full-styling session')
H.ok(client:find("nearestDistance > (Config.interactDistance + 1.0)", 1, true), 'nearest-shop client feedback uses the same tolerance as the authoritative server check')
H.ok(server:find("elseif mode == 'admin' then", 1, true) and server:find("exports.qbcore:hasPermission(src, 'admin')", 1, true), 'full-styling admin sessions are permission-checked server-side')
H.ok(client:find("RegisterNetEvent('qb-clothing:client:loadOutfit'", 1, true), 'real qb-clothing loadOutfit event is implemented')
H.ok(client:find("exports('OpenClothingRoom'", 1, true), 'real qb-clothing OpenClothingRoom export is implemented')
H.ok(client:find("exports('ApplyAppearanceToPed'", 1, true), 'local preview peds can use qbclothing\'s bounded appearance application')
H.ok(manifest:find("provide 'qb-clothing'", 1, true), 'manifest advertises the qb-clothing identity')

-- The character-creation hook is a listener: it arms on the event qbcore
-- already fires and opens on the completion event qbmultichar publishes.
H.ok(client:find("RegisterNetEvent('qb-multicharacter:client:closeNUIdefault'", 1, true), 'hooks the existing new-character signal')
H.ok(client:find("AddEventHandler('qbmultichar:client:spawnComplete'", 1, true),
    'first-character clothing opens on qbmultichar\'s spawn-completion event, not on a timer -- ' ..
    'the qbmultichar:mode bag it used to poll is cleared BEFORE the teleport runs, so a poller ' ..
    'woke while the ped was still being placed and put the fitting room on screen pre-spawn')
H.ok(client:find("if isNew ~= true then return end", 1, true), 'an ordinary login never opens the creation fitting room')
H.ok(client:find("local function hasSpawnCompleteSignal()", 1, true) and client:find("GetResourceState('qbmultichar') == 'started'", 1, true),
    'third-party qb-multicharacter, which publishes no completion event, keeps the ped-observing fallback -- ' ..
    'asked at arm time, since a chunk-load read can catch qbmultichar still starting in the same batch')
H.ok(client:find('NetworkIsPlayerActive(PlayerId())', 1, true), 'the fallback path waits for the player to actually be spawned before opening')

-- A saved outfit must reappear on every future login, not just persist
-- silently in the database -- regression guard for that re-apply path. The
-- callback trigger is a network round trip, so a fitting-room session can
-- legitimately open while it's in flight -- a late-arriving apply must not
-- clobber whatever the player is currently trying on.
H.ok(client:find("RegisterNetEvent('QBCore:Client:OnPlayerLoaded'", 1, true), 'saved appearance is re-applied on every login')
H.ok(client:find("QB.callback.trigger('qb-clothing:server:getSkin')", 1, true), 'login re-apply uses the real qb-clothing getSkin callback')
H.ok(client:find('if not model or activeSession then return end', 1, true), 'a late login re-apply is dropped if a fitting-room session opened in the meantime')

-- What gets reported to the NUI/server as the current model must be read
-- back off the live ped, never echoed from a request that may have failed to
-- stream in time (RequestModel can legitimately time out).
H.ok(client:find('local function currentModelName(ped)', 1, true), 'current model is derived from the live ped, not trusted from a request')
H.ok(client:find('model = currentModelName(ped),', 1, true), 'session-open payload reports the actual applied model')
H.ok(client:find('model = currentModelName(ped),\n        categories = buildCategoryPayload(ped, activeSession.service),', 1, true), 'loadOutfit response reports the actual applied model and service-filtered categories')
H.ok(client:find('model = currentModelName(ped),\n        skin = currentSkinSnapshot(ped),', 1, true), 'confirm submits the actual applied model')

-- NUI is this resource's own frame -- raw natives only, never qblib's QB.nui.*
-- (which would dispatch into qblib's own VM/frame instead of this one).
H.ok(client:find('SendNUIMessage', 1, true) and client:find('RegisterNUICallback', 1, true), 'client owns its own NUI transport')
do
    -- Strip comments first: the file's own header explains, in prose, why
    -- QB.nui.* must NOT be used here -- that explanatory text itself contains
    -- the substring and would otherwise false-positive this check.
    local codeOnly = client:gsub("%-%-[^\n]*", '')
    H.ok(not codeOnly:find('QB.nui.', 1, true), 'client never routes its own NUI through qblib\'s proxy')
end
H.ok(not server:find('SendNUIMessage', 1, true) and not server:find('RegisterNUICallback', 1, true), 'server has no NUI authority')

-- The preview camera must never accept a position with world geometry between
-- it and the ped -- a shop counter, a parked car or a passing ped otherwise
-- sits in shot. Ported from qbmultichar's scene.lua: capsule (not ray) trace,
-- fan around the obstruction at the same distance first, pull in only as a
-- last resort. Re-resolved on every zone/zoom change, not just at start.
H.ok(camera:find('local function traceCameraPath(subject, candidate)', 1, true), 'the camera capsule-traces its own path to the ped')
H.ok(camera:find('StartShapeTestCapsule(', 1, true), 'a capsule, not a zero-width ray -- the camera must not graze a wall or column edge')
H.ok(camera:find('local CAMERA_FAN_ANGLES = { 0.0, 28.0, -28.0, 55.0, -55.0, 82.0, -82.0, 180.0 }', 1, true), 'an obstruction is first solved by fanning around the ped at the same distance')
H.ok(camera:find('occlusion.radiusScale = clamp((distance - 0.25) / radius', 1, true), 'pulling the camera in towards the ped is the last resort, not the first')
H.ok(camera:find('occlusionDirty = true', 1, true) and camera:find('if occlusionDirty then', 1, true), 'the resolve is re-run on zone/zoom changes, coalesced rather than per-frame')

-- Free wheel zoom must not fight the zone lerp for ownership of state.radius:
-- it moves the GOAL the lerp is already chasing.
H.ok(camera:find('function Camera.zoom(delta)', 1, true), 'the camera exposes a continuous zoom')
H.ok(camera:find('local function goalRadius(zoneCfg)', 1, true) and camera:find('lerp(state.radius, goalRadius(zoneCfg), zoomRate)', 1, true),
    'free zoom is folded into the zone lerp goal, not written onto the live camera radius')
H.ok(config:find('zoom = {', 1, true) and config:find('step = 0.12,', 1, true), 'zoom bounds and step are configurable')
H.ok(client:find("RegisterNUICallback('qbclothing:nui:zoom'", 1, true), 'the NUI can request a continuous zoom')
H.ok(camera:find('target.zoomOffset = 0.0\n    occlusionDirty = true', 1, true), 'a zone preset is a jump-to: it discards the accumulated free-zoom offset')

-- Hair colour is a pair of PALETTE INDICES, never RGB -- SetPedHairColor
-- accepts nothing else. Server clamps coarsely, client re-clamps against the
-- live palette, and the NUI paints swatches from GetPedHairRgbColor so the
-- indexed native is never fronted by a fake free colour picker.
H.ok(shared:find('function Shared.clampHairColor(value)', 1, true), 'hair colour indices are validated by one shared clamp')
H.ok(server:find('skin.hairColor = Shared.clampHairColor(rawSkin.hairColor)', 1, true), 'submitted hair colour is clamped server-side like every other index')
H.ok(server:find('local hairSource = idAllowed(policy.components, 2) and requested or before', 1, true), 'hair colour is gated by the same whitelist as the hair component itself')
H.ok(server:find('touchedCategories[Shared.components[2].category] = true', 1, true), 'a recolour-only barber visit is still priced')
H.ok(server:find('local function hairOf(skin) return (skin.hairColor or 0), (skin.hairHighlight or 0) end', 1, true), 'outfits saved before hair colour existed still match as owned')
H.ok(client:find('local function buildHairPalette()', 1, true) and client:find('GetPedHairRgbColor(index)', 1, true), 'the palette the NUI paints is read from the game, not hardcoded')
H.ok(client:find('SetPedHairColor(ped, previewHair.color, previewHair.highlight)', 1, true), 'hair colour reaches the ped through the indexed native')
H.ok(client:find("RegisterNUICallback('qbclothing:nui:setHairColor'", 1, true), 'the NUI can preview a hair recolour')
H.ok(client:find('hair = hairPayload(activeSession.service),', 1, true), 'the palette is sent once with the session payload')
H.ok(client:find('if not policyAllows(policy, policy.components, 2) then return nil end', 1, true), 'a clothing shop is sent no palette at all')

-- Shop interaction is geometry, not a ped: a ped-bound target dies with the
-- ped (unstreamed model, shoved out of place, deleted by another resource) and
-- leaves the shop silently unopenable.
H.ok(not client:find('exports.qbtarget:addEntity', 1, true), 'shops are no longer targeted through a spawned clerk entity')
H.ok(client:find('exports.qbtarget:addBoxZone({', 1, true) and client:find('exports.qbtarget:addPolyZone({', 1, true), 'shops are targeted through qbtarget zone geometry')
H.ok(client:find('options = options,', 1, true), 'the zone APIs take options INSIDE the opts table, unlike addEntity')
H.ok(config:find('Config.shopPeds = false', 1, true), 'the decorative clerk is off by default')
H.ok(client:find('if Config.shopPeds then', 1, true), 'the clerk is spawned only when configured, and carries no target options')
H.ok(client:find('QB.blips.create(shop.coords, shop.blip)', 1, true), 'the blip still works off shop.coords')

-- Camera never leaks a render-cams state or a stuck control lock.
H.ok(camera:find('function Camera.stop()', 1, true), 'camera exposes an explicit stop')
H.ok(camera:find('RenderScriptCams(false, true, 300, true, true)', 1, true), 'camera stop restores the gameplay cam')
H.ok(client:find('stopControlLock()', 1, true), 'closing a session releases the control lock')

-- Migration follows qbinventory's exact convention: checksummed file handed
-- to qbsql's Migrator, no custom runner.
H.ok(persistence:find('QB.sql.migrate(resource, migrations)', 1, true), 'schema uses qbsql\'s migrator')
H.ok(persistence:find("{ version = 1, name = 'playerskins_outfits', file = 'sql/001_playerskins_outfits.sql' }", 1, true), 'migration list matches the shipped sql file')

H.finish()

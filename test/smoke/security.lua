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
H.ok(server:find("RegisterNetEvent('qbclothing:server:requestSession'", 1, true), 'session open is an explicit transport')
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
H.ok(server:find("if session.mode ~= 'firstCharacter' and before and not ownedOutfitMatch(session.citizenid, model, newSkin) then", 1, true), 'every session mode except the one-time fitting is priced, not just shop')
H.ok(server:find('local beforeSkin = (before and before.skin) or { components = {}, props = {} }', 1, true), 'an empty placeholder baseline exists only for the revert path, never for pricing')
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
H.ok(server:find('local wantsBox = session.mode ~= ' .. "'firstCharacter'" .. ' and Config.clothingAsItem', 1, true), 'the free first-fitting never boxes as an item, only equips directly')
H.ok(server:find('revertTo = boxed and { model = beforeModel, skin = beforeSkin } or nil', 1, true), 'a boxed purchase reverts the live try-on preview instead of leaving it worn')
H.ok(client:find("RegisterNetEvent('qbclothing:client:wearItem'", 1, true), 'client applies an equipped item on use')
H.ok(client:find('if activeSession then return end', 1, true), 'wearing an item is ignored while a fitting-room session is open')

-- Appearance is clamped server-side even though the true per-model cap can
-- only be known client-side.
H.ok(server:find('local function sanitiseSkin(rawSkin)', 1, true), 'submitted skin data is sanitised before persistence')
H.ok(server:find('local function clampIndex(value)', 1, true), 'drawable/texture indices are clamped')

-- Real qb-clothing / qb-multicharacter wire-protocol compat.
H.ok(server:find("QB.callback.register('qb-clothing:server:getSkin'", 1, true), 'real qb-clothing getSkin callback is implemented')
H.ok(server:find("QB.callback.register('qb-multicharacter:server:getSkin'", 1, true), 'qbmultichar character-select preview callback is overridden')
H.ok(client:find("RegisterNetEvent('qb-clothing:client:CreateFirstCharacter'", 1, true), 'real qb-clothing CreateFirstCharacter event is implemented')
H.ok(client:find("RegisterNetEvent('qb-clothing:client:openMenu'", 1, true), 'real qb-clothing openMenu event is implemented')
H.ok(client:find("RegisterNetEvent('qb-clothing:client:openOutfitMenu'", 1, true), 'real qb-clothing openOutfitMenu event is implemented')
H.ok(client:find("RegisterNetEvent('qb-clothing:client:loadOutfit'", 1, true), 'real qb-clothing loadOutfit event is implemented')
H.ok(client:find("exports('OpenClothingRoom'", 1, true), 'real qb-clothing OpenClothingRoom export is implemented')
H.ok(manifest:find("provide 'qb-clothing'", 1, true), 'manifest advertises the qb-clothing identity')

-- The character-creation hook must be additive -- it only listens on an
-- event qbcore/qbmultichar already fire, never edits either resource.
H.ok(client:find("RegisterNetEvent('qb-multicharacter:client:closeNUIdefault'", 1, true), 'hooks the existing new-character signal')
H.ok(client:find('NetworkIsPlayerActive(PlayerId())', 1, true), 'waits for the player to actually be spawned before opening')

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
H.ok(client:find('cb({ ok = true, model = currentModelName(ped), categories =', 1, true), 'loadOutfit response reports the actual applied model')
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

-- Camera never leaks a render-cams state or a stuck control lock.
H.ok(camera:find('function Camera.stop()', 1, true), 'camera exposes an explicit stop')
H.ok(camera:find('RenderScriptCams(false, true, 300, true, true)', 1, true), 'camera stop restores the gameplay cam')
H.ok(client:find('stopControlLock()', 1, true), 'closing a session releases the control lock')

-- Migration follows qbinventory's exact convention: checksummed file handed
-- to qbsql's Migrator, no custom runner.
H.ok(persistence:find('QB.sql.migrate(resource, migrations)', 1, true), 'schema uses qbsql\'s migrator')
H.ok(persistence:find("{ version = 1, name = 'playerskins_outfits', file = 'sql/001_playerskins_outfits.sql' }", 1, true), 'migration list matches the shipped sql file')

H.finish()

-- Optional FFT development hooks (server). Listed last in fxmanifest.lua and
-- inert unless `setr fft_kora_hooks true`. No other file references FFT.
--
-- A confirmed fitting overwrites the character's playerskins row and can add a
-- playeroutfits row, and the resource has no export that reads either table.
-- This hook lets a suite read the tester's own rows (to assert what the server
-- stored) and put them back afterwards: the saved appearance exactly as it was
-- (including "no row"), and any outfit whose name carries the test prefix. It
-- only ever touches rows of the tester's own citizen id.
if GetConvar('fft_kora_hooks', 'false') ~= 'true' then return end

local RUNNER = 'fft'
local VERSION = 1
local OUTFIT_PREFIX = 'fft-'
local MAX_SKIN_BYTES = 200000

local function citizenFor(src)
    if type(src) ~= 'number' or src < 1 or not GetPlayerName(src) then return nil end
    if type(Player(src).state.fftSession) ~= 'string' then return nil end
    local ok, citizenid = pcall(function() return exports.kora_core:getPlayerData(src, { 'citizenid' }) end)
    if not ok or type(citizenid) ~= 'string' or citizenid == '' then return nil end
    return citizenid
end

local function skinText(value)
    if type(value) == 'string' then return value end
    if type(value) == 'table' then return json.encode(value) end
    return '{}'
end

local actions = {}

---The tester's saved appearance row: { exists, model, skin } with `skin` as the
---stored JSON text. Opaque to the caller; pass it back to restoreSkin.
function actions.skin(citizenid)
    local row, err = Kora.sql.single('SELECT `model`, `skin` FROM `playerskins` WHERE `citizenid` = ?', { citizenid })
    if err then return false, 'Could not read playerskins: ' .. tostring(err), 'rejected' end
    if not row then return true, { exists = false } end
    local text = skinText(row.skin)
    if #text > MAX_SKIN_BYTES then return false, 'Saved appearance is too large to snapshot', 'rejected' end
    return true, { exists = true, model = row.model, skin = text }
end

---Puts back a snapshot taken with `skin`: rewrites the row, or deletes it when
---the tester had none.
function actions.restoreSkin(citizenid, snapshot)
    if type(snapshot) ~= 'table' or type(snapshot.exists) ~= 'boolean' then return false, 'Invalid snapshot', 'invalid' end
    if not snapshot.exists then
        local ok, result = pcall(Kora.sql.execute, 'DELETE FROM `playerskins` WHERE `citizenid` = ?', { citizenid })
        if not ok or result == nil then return false, 'Could not remove the saved appearance', 'rejected' end
        return true
    end
    if type(snapshot.model) ~= 'string' or #snapshot.model > 64 or type(snapshot.skin) ~= 'string'
        or #snapshot.skin > MAX_SKIN_BYTES or snapshot.skin:sub(1, 1) ~= '{' and snapshot.skin:sub(1, 1) ~= '[' then
        return false, 'Invalid snapshot', 'invalid'
    end
    local ok, result = pcall(Kora.sql.execute,
        'INSERT INTO `playerskins` (`citizenid`, `model`, `skin`) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `model` = VALUES(`model`), `skin` = VALUES(`skin`)',
        { citizenid, snapshot.model, snapshot.skin })
    if not ok or result == nil then return false, 'Could not restore the saved appearance', 'rejected' end
    return true
end

---The tester's saved outfits as { id, name, model }.
function actions.outfits(citizenid)
    local rows = Kora.sql.query(
        'SELECT `id`, `outfitname`, `model` FROM `playeroutfits` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 60',
        { citizenid }) or {}
    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = { id = tonumber(row.id), name = row.outfitname, model = row.model } end
    return true, out
end

---Deletes the tester's outfits whose name starts with the test prefix.
function actions.deleteTestOutfits(citizenid)
    local ok, result = pcall(Kora.sql.execute,
        'DELETE FROM `playeroutfits` WHERE `citizenid` = ? AND LEFT(`outfitname`, ?) = ?',
        { citizenid, #OUTFIT_PREFIX, OUTFIT_PREFIX })
    if not ok or result == nil then return false, 'Could not delete test outfits', 'rejected' end
    return true
end

exports('fftVersion', function() return VERSION end)
exports('fftAction', function(action, src, ...)
    if GetInvokingResource() ~= RUNNER then return false, 'FFT hooks are disabled or session is not authorised' end
    local citizenid = citizenFor(src)
    if not citizenid then return false, 'FFT hooks are disabled or session is not authorised' end
    local handler = actions[action]
    if not handler then return false, 'Unsupported FFT action: ' .. tostring(action) end
    return handler(citizenid, ...)
end)

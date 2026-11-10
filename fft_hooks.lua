-- Optional FFT development hooks (client). Listed last in fxmanifest.lua and
-- inert unless `setr fft_kora_hooks true`. No other file references FFT.
--
-- The fitting room is a NUI page: client/client.lua sends it messages through
-- the raw SendNUIMessage native (looked up as a global at call time, never
-- captured as a local) and takes its answers through RegisterNUICallback. The
-- session itself is file-local. This hook therefore:
--   * OBSERVES the messages sent to the page by wrapping the global
--     SendNUIMessage and keeping a bounded log (every message is forwarded
--     unchanged).
-- The page's own NUI callbacks are not run from here: the suite calls them
-- with a real fetch (FFT's K.nui), because a script-fired __cfx_nui event is
-- never answered.
-- It proves the Lua <-> NUI contract, not what the page renders.
if GetConvar('fft_kora_hooks', 'false') ~= 'true' then return end

local RUNNER = 'fft'
local VERSION = 2
local MAX_LOG = 100

local function session()
    if GetResourceState(RUNNER) ~= 'started' then return nil end
    local id = LocalPlayer.state.fftSession
    return type(id) == 'string' and id or nil
end

local sequence = 0
local log = {}

-- Bounded, JSON-safe copy: functions and deep or huge values never leave the VM.
local function summary(value, depth)
    depth = depth or 0
    local kind = type(value)
    if kind == 'string' then return #value > 200 and (value:sub(1, 200) .. '...') or value end
    if kind == 'number' or kind == 'boolean' or value == nil then return value end
    if kind ~= 'table' then return '<' .. kind .. '>' end
    if depth >= 3 then return '<table>' end
    local out, count = {}, 0
    for key, item in pairs(value) do
        count = count + 1
        if count > 40 then out['...'] = 'truncated' break end
        out[type(key) == 'number' and key or tostring(key)] = summary(item, depth + 1)
    end
    return out
end

-- The open payload carries whole catalogues (categories, tattoos, strings);
-- only the fields that describe the session are kept.
local OPEN_FIELDS = { 'mode', 'service', 'free', 'mandatory', 'shopLabel', 'model', 'outfits', 'money', 'prices', 'currency' }

local PREFIX = 'kora_clothing:nui:'

local function record(message)
    if type(message) ~= 'table' or type(message.action) ~= 'string' then return end
    if message.action:sub(1, #PREFIX) ~= PREFIX then return end
    local data = message.data
    if message.action == 'kora_clothing:nui:open' and type(data) == 'table' then
        local kept = {}
        for _, field in ipairs(OPEN_FIELDS) do kept[field] = data[field] end
        kept.categoryCount = type(data.categories) == 'table' and #data.categories or 0
        data = kept
    end
    sequence = sequence + 1
    log[#log + 1] = { seq = sequence, action = message.action, data = summary(data) }
    if #log > MAX_LOG then table.remove(log, 1) end
end

local original = SendNUIMessage
local wrapped = type(original) == 'function'
if wrapped then
    SendNUIMessage = function(message, ...)
        if session() then
            local ok, err = pcall(record, message)
            if not ok then print('[kora_clothing:fft] observer failed: ' .. tostring(err)) end
        end
        return original(message, ...)
    end
end

local actions = {}

function actions.state()
    return {
        wrapped = wrapped,
        sequence = sequence,
        focused = IsNuiFocused() == true,
        cameraActive = type(Camera) == 'table' and Camera.isActive() == true or false,
        cameraZone = type(Camera) == 'table' and summary(Camera.currentZone()) or nil,
        interactionMode = type(Config) == 'table' and summary(Config.interactionMode) or nil,
    }
end

---Messages sent to the page after sequence `since`, optionally one action only.
function actions.log(since, action)
    since = tonumber(since) or 0
    if action ~= nil and (type(action) ~= 'string' or #action > 64) then return false, 'Invalid action filter', 'invalid' end
    local out = {}
    for _, entry in ipairs(log) do
        if entry.seq > since and (action == nil or entry.action == action) then out[#out + 1] = entry end
    end
    return out
end

---Whether the server holds a saved appearance for this character, read with
---the callback client.lua uses on login. Read-only.
function actions.savedSkin()
    local model, skin = Kora.callback.trigger('qb-clothing:server:getSkin')
    return true, { exists = model ~= nil, model = summary(model), hasSkin = type(skin) == 'table' }
end

---The legacy qb-clothing outfit list for this character (ids and names only).
function actions.outfits()
    local rows = Kora.callback.trigger('qb-clothing:server:getOutfits')
    if type(rows) ~= 'table' then return false, 'getOutfits answered with ' .. type(rows), 'rejected' end
    local out = {}
    for index, row in ipairs(rows) do
        if index > 40 then break end
        if type(row) == 'table' then out[#out + 1] = { id = tonumber(row.id), name = summary(row.outfitname), model = summary(row.model) } end
    end
    return true, out
end

exports('fftVersion', function() return VERSION end)
exports('fftAction', function(action, ...)
    if GetInvokingResource() ~= RUNNER or not session() then
        return false, 'FFT hooks are disabled or session is not authorised'
    end
    local handler = actions[action]
    if not handler then return false, 'Unsupported FFT action: ' .. tostring(action) end
    return handler(...)
end)

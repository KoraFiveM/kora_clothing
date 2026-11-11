-- Schema bootstrap for playerskins/playeroutfits: the tables are declared in
-- server/schema.lua and applied through kora_sql's declarative schema handler.

KoraClothing = KoraClothing or {}
local P = {}
KoraClothing.persistence = P

local state = { ready = false, lastError = nil }

local function log(level, message)
    print(('^%s[kora_clothing:persistence]^7 %s'):format(level, message))
end

function P.ready()
    return state.ready
end

local function bootstrap()
    local sqlReady, readyErr = Kora.sql.ready(60000)
    if not sqlReady then
        state.lastError = readyErr or 'kora_sql did not become ready'
        log('1', state.lastError)
        return
    end

    local reports, schemaErr = Kora.sql.ensureTables(KoraClothingSchema)
    if schemaErr then
        state.lastError = schemaErr
        log('1', ('schema setup failed: %s'):format(schemaErr))
        return
    end
    for _, report in ipairs(reports or {}) do
        for _, warning in ipairs(report.warnings or {}) do
            log('3', ('%s: %s'):format(tostring(report.table), tostring(warning)))
        end
    end

    state.ready = true
    log('2', 'playerskins/playeroutfits schema ready.')
    TriggerEvent('kora_clothing:server:persistenceReady')
end

CreateThread(bootstrap)

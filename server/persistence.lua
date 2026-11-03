-- Schema bootstrap for playerskins/playeroutfits: the tables are declared in
-- server/schema.lua and applied through kora_sql's declarative schema handler.

QbClothing = QbClothing or {}
local P = {}
QbClothing.persistence = P

local state = { ready = false, lastError = nil }

local function log(level, message)
    print(('^%s[qbclothing:persistence]^7 %s'):format(level, message))
end

function P.ready()
    return state.ready
end

local function bootstrap()
    local sqlReady, readyErr = Kora.sql.ready(60000)
    if not sqlReady then
        state.lastError = readyErr or 'qbsql did not become ready'
        log('1', state.lastError)
        return
    end

    local reports, schemaErr = Kora.sql.ensureTables(QbClothingSchema)
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
    TriggerEvent('qbclothing:server:persistenceReady')
end

CreateThread(bootstrap)

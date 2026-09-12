-- Schema bootstrap for playerskins/playeroutfits, following qbinventory's
-- exact migration convention (server/persistence.lua): read the .sql file,
-- checksum it, hand both to qbsql's Migrator via QB.sql.migrate. qbsql tracks
-- applied (resource, version) pairs itself -- no custom runner needed here.

QbClothing = QbClothing or {}
local P = {}
QbClothing.persistence = P

local resource = GetCurrentResourceName()
local state = { ready = false, lastError = nil }

local function log(level, message)
    print(('^%s[qbclothing:persistence]^7 %s'):format(level, message))
end

local function fnv1a(str)
    local hash, prime = 0xCBF29CE484222325, 0x100000001B3
    for i = 1, #str do
        hash = hash ~ string.byte(str, i)
        hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF
    end
    return hash
end

-- Matches qbinventory's checksum format exactly (two 64-bit FNV-1a hex
-- halves, zero-padded to qbsql's expected 64 hex chars) -- qbsql's Migrator
-- only cares that the same source always produces the same checksum.
local function checksum(str)
    local a, b = fnv1a(str), fnv1a(str:reverse())
    return ('%016x%016x'):format(a, b) .. string.rep('0', 32)
end

local MIGRATIONS = {
    { version = 1, name = 'playerskins_outfits', file = 'sql/001_playerskins_outfits.sql' },
}

function P.ready()
    return state.ready
end

local function bootstrap()
    local sqlReady, readyErr = QB.sql.ready(60000)
    if not sqlReady then
        state.lastError = readyErr or 'qbsql did not become ready'
        log('1', state.lastError)
        return
    end

    local _, migrationErr = QB.sql.migrateFiles(resource, MIGRATIONS, checksum)
    if migrationErr then
        state.lastError = migrationErr
        log('1', ('schema migration failed: %s'):format(migrationErr))
        return
    end

    state.ready = true
    log('2', 'playerskins/playeroutfits schema ready.')
    TriggerEvent('qbclothing:server:persistenceReady')
end

CreateThread(bootstrap)

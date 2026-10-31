-- Tattoo stacking: the same tattoo id repeated is kept (up to Config.tattoo.maxStack),
-- validated and priced per added instance, and survives persistence/skin matching.
local H = dofile('test/harness.lua')

local function read(path)
    local file = assert(io.open(path, 'r'))
    local source = file:read('*a')
    file:close()
    return source
end

Config = {
    testMode = true,
    tattoo = { allowStacking = true, maxStack = 3, stackPriceMultiplier = 1.0 },
    tattoos = {
        { id = 'turbulence', label = 'Turbulence', group = 'Torso', collection = 'mpairraces_overlays', male = 'M_000', female = 'F_000', price = 125 },
        { id = 'anchor', label = 'Anchor', group = 'Arms', collection = 'mphipster_overlays', male = 'M_ANCHOR', female = 'F_ANCHOR', price = 110 },
    },
}
dofile('shared/components.lua')
local male = Shared.models.male
local function join(list) return table.concat(list, ',') end

-- Validation: duplicates kept, unknown ids dropped, each id capped at maxStack.
H.equal(join(Shared.sanitiseTattoos(male, { 'turbulence', 'turbulence', 'anchor' })), 'turbulence,turbulence,anchor', 'duplicates are kept in order')
H.equal(join(Shared.sanitiseTattoos(male, { 'turbulence', 'turbulence', 'turbulence', 'turbulence', 'turbulence' })), 'turbulence,turbulence,turbulence', 'stack count is capped at maxStack')
H.equal(join(Shared.sanitiseTattoos(male, { 'turbulence', 'bogus', 42, 'turbulence' })), 'turbulence,turbulence', 'every instance must be a valid tattoo')
H.equal(#Shared.sanitiseTattoos(male, 'nope'), 0, 'a non-table list is empty')
H.equal(#Shared.sanitiseTattoos('unknown_model', { 'turbulence' }), 0, 'unknown model has no tattoos')
Config.tattoo.maxStack = 2
H.equal(#Shared.sanitiseTattoos(male, { 'turbulence', 'turbulence', 'turbulence' }), 2, 'maxStack is read at use time')
Config.tattoo.maxStack = 99
H.equal(Shared.tattooStacking().max, 10, 'maxStack is clamped to 10')
Config.tattoo.maxStack = 3
Config.tattoo.allowStacking = false
H.equal(join(Shared.sanitiseTattoos(male, { 'turbulence', 'turbulence', 'anchor' })), 'turbulence,anchor', 'stacking off keeps one instance per tattoo')
Config.tattoo.allowStacking = true

-- Pricing is computed from counts server-side.
H.equal(Shared.tattooPriceDiff(male, {}, { 'turbulence' }), 125, 'a first instance costs the tattoo price')
H.equal(Shared.tattooPriceDiff(male, { 'turbulence' }, { 'turbulence', 'turbulence' }), 125, 'an added instance costs like a new tattoo')
H.equal(Shared.tattooPriceDiff(male, {}, { 'turbulence', 'turbulence', 'anchor' }), 360, 'a new stack of two plus another tattoo')
H.equal(Shared.tattooPriceDiff(male, { 'turbulence', 'turbulence' }, { 'turbulence' }), 0, 'removing an instance is free')
H.equal(Shared.tattooPriceDiff(male, { 'turbulence', 'turbulence' }, { 'turbulence', 'turbulence' }), 0, 'existing instances are not charged again')
Config.tattoo.stackPriceMultiplier = 0.5
H.equal(Shared.tattooPriceDiff(male, {}, { 'turbulence', 'turbulence' }), 125 + 63, 'extra instances use stackPriceMultiplier (first stays full price)')
Config.tattoo.stackPriceMultiplier = 1.0

-- Source contracts: no dedupe anywhere on the server/client paths.
local server, client = read('server/server.lua'), read('client/client.lua')
H.ok(server:find('skin.tattoos = Shared.sanitiseTattoos(model, rawSkin.tattoos)', 1, true), 'sanitiseSkin (used for save/confirm/outfits/login) keeps stacked tattoos')
H.ok(not server:find('seen[id] = true', 1, true), 'the server no longer dedupes tattoo ids')
H.ok(server:find('Shared.tattooPriceDiff(model, previousSkin.tattoos, newSkin.tattoos)', 1, true), 'the server prices tattoos itself, including stacked instances')
H.ok(server:find('Shared.tattooCounts(tattoosA)', 1, true), 'skin equality compares tattoo counts, so a stacked look is not treated as an owned one')
H.ok(client:find('return Shared.sanitiseTattoos(model, tattoos)', 1, true), 'the client applies every instance')
H.ok(client:find('tattooStacking = Shared.tattooStacking()', 1, true), 'the studio is told the stack limits')
H.ok(read('config.lua'):find('allowStacking = config and config.boolean(true', 1, true), 'allowStacking has a descriptor')

-- Persistence: playerskins stores the skin JSON as sanitised, so repeats persist.
local function encode(list) return table.concat(list, '|') end
local stored = Shared.sanitiseTattoos(male, { 'turbulence', 'turbulence' })
H.equal(encode(stored), 'turbulence|turbulence', 'a sanitised skin keeps both instances for the persisted JSON')
H.equal(#Shared.sanitiseTattoos(male, stored), 2, 'reload/login sanitising is idempotent and keeps duplicates')

H.finish()

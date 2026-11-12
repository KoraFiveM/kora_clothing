KoraClothingSchema = {
    {
        name = 'playerskins',
        collate = 'utf8mb4_unicode_ci',
        columns = {
            { name = 'citizenid', type = 'varchar(50)' },
            { name = 'model', type = 'varchar(64)' },
            { name = 'skin', type = 'longtext' },
            { name = 'updated_at', type = 'timestamp', default = { raw = 'CURRENT_TIMESTAMP' }, on_update = 'CURRENT_TIMESTAMP' },
        },
        primary = { 'citizenid' },
    },
    {
        name = 'playeroutfits',
        collate = 'utf8mb4_unicode_ci',
        columns = {
            { name = 'id', type = 'int', unsigned = true, auto_increment = true },
            { name = 'citizenid', type = 'varchar(50)' },
            { name = 'outfitname', type = 'varchar(50)' },
            { name = 'model', type = 'varchar(64)' },
            { name = 'skin', type = 'longtext' },
            { name = 'created_at', type = 'timestamp', default = { raw = 'CURRENT_TIMESTAMP' } },
        },
        primary = { 'id' },
        indexes = {
            { name = 'idx_playeroutfits_citizenid', columns = { 'citizenid' } },
        },
    },
}

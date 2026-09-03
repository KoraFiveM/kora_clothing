fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbclothing'
author 'qbcore2'
version '0.1.0'
description 'Clothing, appearance and outfit wardrobe with a private fitting-room bucket'

-- Speaks the REAL qb-clothing wire protocol directly (net events + callback
-- names, matching github.com/qbcore-framework/qb-clothing) rather than a
-- separate modern pair -- same convention as qbmultichar's own manifest
-- comment: any third-party resource built against real qb-clothing (a tattoo
-- shop, a barber, a job-uniform script) keeps working unmodified.
provide 'qb-clothing'

-- Shops are targeted through qbtarget zones; FXServer's `dependency` keyword
-- creates a start-order edge regardless of server.cfg `ensure` position, so
-- this is guaranteed running before client.lua registers zones on resource
-- start.
dependency 'qblib'
dependency 'qbsql'
dependency 'qbcore'
dependency 'qbtarget'

shared_script '@qblib/init.lua'
shared_script '@qbsql/init.lua'

shared_scripts {
    'config.lua',
    'shared/components.lua',
}

server_scripts {
    'server/persistence.lua',
    'server/server.lua',
}

client_scripts {
    'client/camera.lua',
    'client/client.lua',
}

ui_page 'web/build/index.html'

files {
    'sql/001_playerskins_outfits.sql',
    'web/build/index.html',
    'web/build/assets/**/*',
}

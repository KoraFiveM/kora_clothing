fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_clothing'
-- Keep the legacy resource name resolvable for exports['qbclothing'] callers.
provide 'qbclothing'
author 'qbcore2'
version '0.1.0'
description 'Clothing, appearance and outfit wardrobe with a private fitting-room bucket'

-- Speaks the REAL qb-clothing wire protocol directly (net events + callback
-- names, matching github.com/qbcore-framework/qb-clothing) rather than a
-- separate modern pair -- same convention as kora_multichar's own manifest
-- comment: any third-party resource built against real qb-clothing (a tattoo
-- shop, a barber, a job-uniform script) keeps working unmodified.
provide 'qb-clothing'

-- Shops are targeted through kora_target zones; FXServer's `dependency` keyword
-- creates a start-order edge regardless of server.cfg `ensure` position, so
-- this is guaranteed running before client.lua registers zones on resource
-- start.
dependency 'kora_theme'
dependency 'kora_lib'
dependency 'kora_sql'
dependency 'kora_core'
dependency 'kora_target'

shared_script '@kora_lib/init.lua'

shared_scripts {
    'config.lua',
    'shared/components.lua',
}

server_scripts {
    '@kora_sql/init.lua',
    'server/schema.lua',
    'server/persistence.lua',
    'server/server.lua',
}

client_scripts {
    '@kora_theme/client/bridge.lua',
    'client/camera.lua',
    'client/rotate.lua',
    'client/quicktoggle.lua',
    'client/client.lua',
}

ui_page 'web/build/index.html'

files {
    'locales/*.json',
    'web/build/index.html',
    'web/build/assets/**/*',
}

---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Clothing is the clothing/appearance stack: clothing stores, barbers, hairdressers, a tattoo studio, character creation and a saved outfit wardrobe, with its own camera rig for the fitting room. It owns its own NUI frame (`ui_page`) and speaks the real `qb-clothing` wire protocol (net events and callback names) directly, so third-party scripts built against qb-clothing keep working unmodified.

## Install Kora Clothing

1. **Add the folder** — Place `kora_clothing` in your resources directory (`resources/[kora]/kora_clothing` on the Kora recipe).

2. **Have the dependencies running** — The manifest declares `kora_theme`, `kora_lib`, `kora_sql`, `kora_core` and `kora_target` as dependencies, which creates a start-order edge regardless of `server.cfg` `ensure` position. Shops are opened through `kora_target` zones, persistence goes through `Kora.sql`, and money/character data comes from `kora_core` exports.

3. **Start it, then anything that calls its exports** — Resources that call `exports.kora_clothing` (`kora_multichar` for first-character creation and the character-select preview, `kora_admin` for admin appearance sessions) must start after it.

   ```bash title="server.cfg" {6}
   ensure kora_theme
   ensure kora_lib
   ensure kora_sql
   ensure kora_core
   ensure kora_target
   ensure kora_clothing
   # resources that call exports.kora_clothing (kora_multichar, kora_admin) start after it
   ensure kora_multichar
   ensure kora_admin
   ```

4. **Tables are created automatically** — `server/schema.lua` declares `KoraClothingSchema` (`playerskins`, `playeroutfits`) and `server/persistence.lua` waits for `Kora.sql.ready` then applies it with `Kora.sql.ensureTables`, additively, before marking itself ready and firing `kora_clothing:server:persistenceReady`. Nothing needs to be run by hand.

5. **Review the config** — Open `config.lua`: shop/barber/hairdresser/tattoo locations and pricing, the tattoo catalogue, camera framing, rotate-drag behaviour, the quick-toggle chat command and the optional clothing-as-item wardrobe. See Configuration for the groups that matter most.

6. **Optional: clothing as an inventory item** — `Config.clothingAsItem` (off by default) makes a confirmed purchase/save give a physical `kora_clothing_outfit` item instead of equipping directly. Turning it on requires `kora_inventory` running: the resource registers the item with `kora_core` and a use handler with `kora_inventory` itself at start, with no extra setup.

## Manifest reference

`provide 'qb-clothing'` lets any resource built against that name resolve to this one. `shared/components.lua` is the static GTA component/prop/tattoo catalogue and head-overlay helpers (`Shared`); `config.lua` is the owner-editable `Config`. `@kora_theme/client/bridge.lua` wires the camera/menu styling bridge before `client/camera.lua`, `client/rotate.lua` and `client/quicktoggle.lua` load, with `client/client.lua` (the session/menu owner) loading last.

```lua title="fxmanifest.lua"
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_clothing'
provide 'qb-clothing'

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
```

- `locales/*.json` and the `web/build/` React NUI are referenced by `files`/`ui_page`, but their source was not read for this page.
- `config.lua` and `shared/components.lua` are shared scripts, so `Config` and `Shared` exist on both client and server.

## Requirements and database

- The hard dependencies and the optional integrations (kora_multichar, kora_inventory, kora_hud, kora_ambulance, kora_police, kora_admin) are listed in the [Requirements](./index.md#requirements) section of the overview.
- No manual SQL import is needed. The tables `playerskins` and `playeroutfits` are described in [Database](./database.md).
- `Config.clothingAsItem` registers the `kora_clothing_outfit` item itself; see [Items](./items.md).
- Every setting is documented in [Configuration](./api/configuration.md).

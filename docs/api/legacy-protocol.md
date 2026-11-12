---
title: "Legacy qb-clothing protocol"
sidebar_position: 4
---


# Legacy qb-clothing protocol

## Client

Net events kept so any third-party resource built against the real `qb-clothing`/`qb-clothes` wire protocol (a tattoo shop, a barber, a job-uniform script) keeps working unmodified, since this resource `provide`s `qb-clothing`.

Namespace: `qb-clothing:* / kora_clothing:*` · Source: `client/client.lua`

### Events

Pass an options table as the final argument to a play function. Omit the table or any field to use its default.

| Option | Type | Description |
| --- | --- | --- |
| `kora_clothing:client:openNearestShop(service?)` | event | Opens the nearest shop whose `service` matches (default `'clothing'`), computed client-side and re-checked by the server on request. |
| `qb-clothing:client:openMenu(shopType?)` | event | `nil` opens the nearest clothing shop; a number/string or `{ shopId = n }` opens that shop index directly. |
| `qb-clothing:client:openOutfitMenu()` | event | Opens the wardrobe. Same as the `OpenWardrobe`/`getOutfits` exports. |
| `qb-clothing:client:CreateFirstCharacter()` | event | Opens the mandatory first-character creation session directly (normally reached through the kora_multichar spawn-complete flow). |
| `kora_clothing:client:openAdminSession(service?)` | event | Opens an admin session; fired server-side by `OpenAdminSession` or by a self-authorized admin. |
| `qb-clothing:client:loadOutfit(outfit)` | event | Applies a stock qb-clothing `{ outfitData, outfitName, model, skin }` payload onto the live ped (preview, not confirm). |
| `qb-clothing:client:loadPlayerClothing(data, ped?)` | event | Applies a stock qb-clothing outfit table onto an arbitrary ped (defaults to the player's). |
| `qb-clothes:loadSkin(isNew, model, data)` | event | Legacy login/skin-load path; ignored while a session is open or `isNew` is true. |
| `qb-radialmenu:ToggleClothing / ToggleProps / ResetClothing` | event | Forwards to the same local part toggling as the `/c` command (`QuickToggle.run`). |
| `qb-clothing:client:adjustfacewear(kind)` | event | Numeric 1–5 maps to hat/glasses/ears/mask/shirt and toggles that part. |
| `kora_clothing:client:wearItem(model, skin)` | event | Fired server-side when a `kora_clothing_outfit` inventory item (Config.clothingAsItem) is used; applies that exact appearance. |

### Functions

Client-side events.

### Limits and related APIs

A modified client can fire these locally; the server independently re-validates everything a session actually changes (distance, service policy, price, ownership).

### Related guides

- [Client exports](./exports-client.md)

## Server

The server-side half of the same protocol: the tokenised session request/confirm/cancel/delete events, plus the stock qb-clothing/qb-multicharacter callback names.

Namespace: `qb-clothing:* / kora_clothing:*` · Source: `server/server.lua`

### Options

Pass an options table as the final argument to a play function. Omit the table or any field to use its default.

#### Events

| Option | Type | Description |
| --- | --- | --- |
| `kora_clothing:server:requestSession(mode, extra)` | tokenised event (Kora.events) | `mode` is `'shop' \| 'wardrobe' \| 'firstCharacter' \| 'admin'`. The actual entry point behind every `Open*` export and compat event above. |
| `kora_clothing:server:confirmSession(payload)` | tokenised event | `{ skin, saveName? }`. Prices and persists the open session; see How to use → Shops. |
| `kora_clothing:server:cancelSession()` | tokenised event | Cancels the open session (refused for a mandatory one, i.e. first-character creation). |
| `kora_clothing:server:deleteOutfit(id)` | tokenised event | Deletes one `playeroutfits` row owned by the open session's citizen. |
| `qb-clothing:server:removeOutfit(outfitName, outfitId)` | RegisterNetEvent | Legacy stock-compat delete, rate-limited per player; does not require an open session. |

#### Callbacks

| Option | Type | Description |
| --- | --- | --- |
| `qb-clothing:server:getSkin()` | Kora.callback | Returns `model, skin` — the citizen's saved appearance, sanitised. Used on login and by third-party resources expecting the real qb-clothing callback name. |
| `qb-clothing:server:getOutfits()` | Kora.callback | Returns an array of `{ id, outfitId, citizenid, outfitname, model, skin }` for the citizen's saved outfits. Rate-limited (10 calls / 10s). |
| `kora_clothing:server:getOutfitSkin(id)` | Kora.callback | Returns `model, skin` for one saved outfit id, only while the caller has an open session (used by the NUI's outfit preview). |
| `kora_clothing:server:getStarterAppearance()` | Kora.callback | Returns `model, skin` for a brand-new character's starter outfit, or `nil` if the citizen already has a saved appearance. Backs the `applyStarterAppearance` export. |
| `qb-multicharacter:server:getSkin(citizenid)` | Kora.callback | Returns `model, skin` for the character-select preview camera, after checking the caller owns that citizen id (`exports.kora_core:ownsCharacter`). Overrides kora_core's own placeholder stub for this callback name. Cached per source+citizenid. |

### Functions

Server-side events and callbacks.

### Limits and related APIs

`kora_clothing:server:requestSession`/`confirmSession`/`cancelSession`/`deleteOutfit` are registered through `Kora.events` (tokenised), not a raw `RegisterNetEvent`, specifically so a static exploit menu cannot fire them directly — the handlers themselves remain the real authorization (session state, server-computed price, re-checked admin permission).

### Related guides

- [Server export](./exports-server.md)

## Events and callbacks reference (from the code)

The qb-clothing, qb-clothes, qb-multicharacter and qb-radialmenu names are covered in [Compatibility](../compatibility.md). This page lists kora_clothing's own events.

### Client events you can trigger

These are registered with `RegisterNetEvent`, so they can be triggered from another client script with `TriggerEvent` or from the server with `TriggerClientEvent`.

| Event | Payload | Effect |
| --- | --- | --- |
| `kora_clothing:client:openNearestShop` | `service` (string, default `'clothing'`) | Opens the nearest shop of that service (`clothing`, `barber`, `hairdresser`, `tattoo`) if the player is close enough. kora_admin's self-service entries use it. |
| `kora_clothing:client:openAdminSession` | `service` (optional) | Asks for a free `admin` session. The server grants it only if the player has the kora_core `admin` permission or a pending grant from `OpenAdminSession`. Without a service it opens `creation` (clothing, hair, face and tattoos). |

```lua
-- client: open the nearest shop configured with service = 'barber'
TriggerEvent('kora_clothing:client:openNearestShop', 'barber')
```

### Client events sent by the server (internal)

These are sent by kora_clothing's server to drive the menu. Do not trigger them from other resources.

| Event | Payload |
| --- | --- |
| `kora_clothing:client:openSession` | session payload (mode, service, free, mandatory, shopLabel, model, skin, outfits, prices, tattoos, currency, money) |
| `kora_clothing:client:outfitsUpdated` | list of `{ id, outfitname, model }` |
| `kora_clothing:client:sessionError` | `message` (also shown as a notification) |
| `kora_clothing:client:closeSession` | `{ ok, cancelled?, revertTo? }` |
| `kora_clothing:client:wearItem` | `model, skin`. Sent when a `kora_clothing_outfit` item is used. Ignored while a session is open. |

### Server session events (internal, secured)

These go through kora_lib's tokenised `Kora.events` gateway, not plain net events, because they move money and open admin fittings. They cannot be fired with `TriggerServerEvent`. Other resources should use the [exports](./exports-client.md) instead.

| Event | Arguments |
| --- | --- |
| `kora_clothing:server:requestSession` | `mode` (`'firstCharacter'`, `'shop'`, `'wardrobe'`, `'admin'`), `extra` (`{ shopId }` or `{ service }`) |
| `kora_clothing:server:confirmSession` | `{ model, skin, saveName? }` |
| `kora_clothing:server:cancelSession` | none |
| `kora_clothing:server:deleteOutfit` | `outfitId` |

### Local events emitted

| Event | Side | Payload | When |
| --- | --- | --- | --- |
| `kora_clothing:server:persistenceReady` | server | none | After `playerskins` and `playeroutfits` were created or verified at start. |
| `qb-clothing:client:onMenuClose` | client | none | After any fitting-room session closes (confirm or cancel). |
| `kora_voice:server:bucketChanged` | server | `src` | Only if kora_core's `setPlayerBucket` export fails and the bucket is set with the native instead. |

```lua
-- server
AddEventHandler('kora_clothing:server:persistenceReady', function()
    print('kora_clothing tables are ready')
end)
```

### Events and state bags listened to

| Name | Side | Source | Use |
| --- | --- | --- | --- |
| `QBCore:Client:OnPlayerLoaded` | client | kora_core | Apply the saved skin. |
| `kora_core:loggedIn` state bag | client | kora_core | Apply the saved skin on login or resource restart. |
| `qb-multicharacter:client:closeNUIdefault` | client | kora_core | Prepare the first-character fitting. |
| `kora_multichar:client:spawnComplete` | client | kora_multichar | Open the first-character fitting (`isNew = true`). |
| `emsDown` player state bag | client | kora_ambulance | Close menus during last stand. |
| `QBCore:Server:OnPlayerUnload` | server | kora_core | Close the session and restore the bucket. |
| `kora_multichar:mode` state bag | server | kora_multichar | Clear the character-select preview cache when the mode is cleared. |

### Callbacks (kora_lib `Kora.callback`)

| Name | Arguments | Returns | Notes |
| --- | --- | --- | --- |
| `kora_clothing:server:getOutfitSkin` | `outfitId` | `model, skin` | Only during an open session, own outfits only. |
| `kora_clothing:server:getStarterAppearance` | none | `model, skin` | Only for a citizen with no saved appearance. Rate limit 6 per 10 s. |
| `qb-clothing:server:getSkin` | none | `model, skin` | Caller's saved appearance, sanitised. See [Compatibility](../compatibility.md). |
| `qb-clothing:server:getOutfits` | none | outfit list | Rate limit 10 per 10 s. |
| `qb-multicharacter:server:getSkin` | `citizenid` | `model, skin` | Character-select preview, rate limit 20 per 10 s. |

```lua
-- client
local model, skin = Kora.callback.trigger('qb-clothing:server:getSkin')
```

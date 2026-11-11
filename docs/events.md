---
title: Events and callbacks
sidebar_position: 6
---

The qb-clothing, qb-clothes, qb-multicharacter and qb-radialmenu names are covered in [Compatibility](./compatibility.md). This page lists kora_clothing's own events.

## Client events you can trigger

These are registered with `RegisterNetEvent`, so they can be triggered from another client script with `TriggerEvent` or from the server with `TriggerClientEvent`.

| Event | Payload | Effect |
| --- | --- | --- |
| `kora_clothing:client:openNearestShop` | `service` (string, default `'clothing'`) | Opens the nearest shop of that service (`clothing`, `barber`, `hairdresser`, `tattoo`) if the player is close enough. kora_admin's self-service entries use it. |
| `kora_clothing:client:openAdminSession` | `service` (optional) | Asks for a free `admin` session. The server grants it only if the player has the kora_core `admin` permission or a pending grant from `OpenAdminSession`. Without a service it opens `creation` (clothing, hair, face and tattoos). |

```lua
-- client: open the nearest shop configured with service = 'barber'
TriggerEvent('kora_clothing:client:openNearestShop', 'barber')
```

## Client events sent by the server (internal)

These are sent by kora_clothing's server to drive the menu. Do not trigger them from other resources.

| Event | Payload |
| --- | --- |
| `kora_clothing:client:openSession` | session payload (mode, service, free, mandatory, shopLabel, model, skin, outfits, prices, tattoos, currency, money) |
| `kora_clothing:client:outfitsUpdated` | list of `{ id, outfitname, model }` |
| `kora_clothing:client:sessionError` | `message` (also shown as a notification) |
| `kora_clothing:client:closeSession` | `{ ok, cancelled?, revertTo? }` |
| `kora_clothing:client:wearItem` | `model, skin`. Sent when a `kora_clothing_outfit` item is used. Ignored while a session is open. |

## Server session events (internal, secured)

These go through kora_lib's tokenised `Kora.events` gateway, not plain net events, because they move money and open admin fittings. They cannot be fired with `TriggerServerEvent`. Other resources should use the [exports](./exports.md) instead.

| Event | Arguments |
| --- | --- |
| `kora_clothing:server:requestSession` | `mode` (`'firstCharacter'`, `'shop'`, `'wardrobe'`, `'admin'`), `extra` (`{ shopId }` or `{ service }`) |
| `kora_clothing:server:confirmSession` | `{ model, skin, saveName? }` |
| `kora_clothing:server:cancelSession` | none |
| `kora_clothing:server:deleteOutfit` | `outfitId` |

## Local events emitted

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

## Events and state bags listened to

| Name | Side | Source | Use |
| --- | --- | --- | --- |
| `QBCore:Client:OnPlayerLoaded` | client | kora_core | Apply the saved skin. |
| `kora_core:loggedIn` state bag | client | kora_core | Apply the saved skin on login or resource restart. |
| `qb-multicharacter:client:closeNUIdefault` | client | kora_core | Prepare the first-character fitting. |
| `kora_multichar:client:spawnComplete` | client | kora_multichar | Open the first-character fitting (`isNew = true`). |
| `emsDown` player state bag | client | kora_ambulance | Close menus during last stand. |
| `QBCore:Server:OnPlayerUnload` | server | kora_core | Close the session and restore the bucket. |
| `kora_multichar:mode` state bag | server | kora_multichar | Clear the character-select preview cache when the mode is cleared. |

## Callbacks (kora_lib `Kora.callback`)

| Name | Arguments | Returns | Notes |
| --- | --- | --- | --- |
| `kora_clothing:server:getOutfitSkin` | `outfitId` | `model, skin` | Only during an open session, own outfits only. |
| `kora_clothing:server:getStarterAppearance` | none | `model, skin` | Only for a citizen with no saved appearance. Rate limit 6 per 10 s. |
| `qb-clothing:server:getSkin` | none | `model, skin` | Caller's saved appearance, sanitised. See [Compatibility](./compatibility.md). |
| `qb-clothing:server:getOutfits` | none | outfit list | Rate limit 10 per 10 s. |
| `qb-multicharacter:server:getSkin` | `citizenid` | `model, skin` | Character-select preview, rate limit 20 per 10 s. |

```lua
-- client
local model, skin = Kora.callback.trigger('qb-clothing:server:getSkin')
```

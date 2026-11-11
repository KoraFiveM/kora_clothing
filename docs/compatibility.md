---
title: Compatibility
sidebar_position: 9
---

kora_clothing declares `provide 'qb-clothing'` and implements the upstream qb-clothing names directly, so resources written for qb-clothing (barbers, tattoo shops, uniform scripts, radial menus, multicharacter) keep working. Appearances are stored in kora_clothing's own format. Stock qb-clothing outfit data is converted when it is applied.

## Client events

| Event | Payload | Effect |
| --- | --- | --- |
| `qb-clothing:client:CreateFirstCharacter` | none | Asks for the free, mandatory first-character fitting. The server refuses it if the citizen already has a saved appearance. |
| `qb-clothing:client:openMenu` | shop index, `{ shopId = n }`, or nothing | Opens that shop. With no argument, opens the nearest clothing shop. A non-numeric value opens shop 1. |
| `qb-clothing:client:openOutfitMenu` | none | Opens the wardrobe. |
| `qb-clothing:client:loadOutfit` | see below | Applies an outfit to the player ped. |
| `qb-clothing:client:loadPlayerClothing` | `data, ped` | Applies a stock qb-clothing skin table (or its JSON) to a freemode ped. `ped` defaults to the player ped. |
| `qb-clothing:client:adjustfacewear` | `1` to `5` | Quick-toggles hat (1), glasses (2), ears (3), mask (4), shirt (5). |
| `qb-clothes:loadSkin` | `isNew, model, data` | Applies a skin (Kora or stock format). Ignored when `isNew` is `true` or a session is open. |
| `qb-radialmenu:ToggleClothing` / `qb-radialmenu:ToggleProps` | part name or `{ id }` | Quick-toggles the matching part on the player's own ped. |
| `qb-radialmenu:ResetClothing` | none | Puts every quick-toggled item back. |

Emitted: `qb-clothing:client:onMenuClose` when a session closes, and `qb-clothing:client:reloadOutfits` (server to client) after `qb-clothing:server:removeOutfit`. That event carries the remaining outfits, or `nil` if none are left.

### loadOutfit payloads

```lua
-- Kora format: model and skin applied directly (freemode models only)
TriggerEvent('qb-clothing:client:loadOutfit', { model = 'mp_m_freemode_01', skin = skin })

-- stock qb-clothing format: keys laid over the current ped, the model is never changed
TriggerEvent('qb-clothing:client:loadOutfit', {
    outfitData = { pants = { item = 24, texture = 0 }, shoes = { item = 10, texture = 0 } },
    outfitName = 'Work',
})
```

Stock keys: `face`, `mask`, `hair`, `arms`, `pants`, `bag`, `shoes`, `accessory`, `t-shirt`, `vest`, `decals`, `torso2` (components) and `hat`, `glass`, `ear`, `watch`, `bracelet` (props). `face` is ignored by `loadOutfit`. For `hair`, the stock `texture` is used as both hair colour and highlight. For props, `item` 0 or lower removes the prop. In `loadPlayerClothing` and `qb-clothes:loadSkin`, `face.texture` sets the skin tone and `beard` / `eyebrows` set those overlays (`item` style, `texture` colour).

### Radial menu part names

`top` / `shirt`, `pants`, `shoes`, `neck` (chain), `mask`, `vest`, `bag` / `bagoff`, `hat`, `glasses`, `visor`, `ear`, `watch`, `bracelet`.

## Server events and callbacks

| Name | Kind | Behaviour |
| --- | --- | --- |
| `qb-clothing:server:getSkin` | callback | Returns `model, skin` (sanitised Kora format) for the caller's character, or nil. |
| `qb-clothing:server:getOutfits` | callback | The caller's outfits: `{ id, outfitId, citizenid, outfitname, model, skin }`, where `outfitId` is the string ID and `skin` is in Kora format. Rate limit 10 per 10 s. |
| `qb-clothing:server:removeOutfit` | net event | `(outfitName, outfitId)`. Deletes the caller's own outfit if both name and ID match. 2 s cooldown. |
| `qb-clothes:loadPlayerSkin` | net event | Replies to the caller with `qb-clothes:loadSkin` (`true` if there is no saved freemode skin, else `false, model, skin`). 2 s cooldown. |
| `qb-multicharacter:server:getSkin` | callback | `(citizenid)`, returns `model, skin` for the character-select preview. kora_core's `ownsCharacter` must confirm that the requesting license owns the character. Rate limit 20 per 10 s. Cached per source until kora_multichar clears its `kora_multichar:mode` state bag. Replaces kora_core's placeholder. |

`qb-clothing:saveSkin` and `qb-clothes:saveOutfit` are intentionally **not** provided: appearance changes are only saved through a server-validated session.

## Exports

`OpenClothingRoom`, `OpenWardrobe`, `getOutfits`, `reloadSkin` and `IsCreatingCharacter` match qb-clothing names. See [Exports](./exports.md).

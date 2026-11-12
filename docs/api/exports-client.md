---
title: "Client exports"
sidebar_position: 2
---


# Client exports

Client-side exports for opening a fitting-room session, querying session state, and applying a saved appearance to a ped the caller controls.

Namespace: `exports.kora_clothing` · Source: `client/client.lua`

## How it works

Every `Open*` export is fire-and-forget: it requests a session from the server over `Kora.events`, which re-validates distance, permission and pricing before the NUI actually opens. None of these exports return session data directly — read state through `IsClothingMenuOpen`/`IsCreatingCharacter`, or via the legacy server callbacks for outfit data (see Legacy protocol).

## Open the clothing store from an NPC or a shop script

1. **Check the player is where you expect** — The export itself does not check distance for a non-shop open; `OpenClothingRoom` still goes through the server's own `nearShop` check against the real `Config.shops` entry.
2. **Call the export** — `exports.kora_clothing:OpenClothingRoom({ shopId = n })` or `OpenWardrobe()`.
3. **Let the resource own the rest** — Confirm/cancel, pricing, persistence and NUI close are all handled internally; there is nothing further to drive from the caller.

## Terms used on this page

| Term | Meaning |
| --- | --- |
| Session | The single `activeSession` the client tracks while the fitting-room NUI is open: mode (shop/wardrobe/firstCharacter/admin), service, and whether it is mandatory (uncancellable). |
| Freemode model | Only `mp_m_freemode_01`/`mp_f_freemode_01` (`Shared.models`) are recognised appearance models; anything else is rejected by `ApplyAppearanceToPed` and the sanitisers. |

## Functions

Nine exports.

### `exports.kora_clothing:OpenClothingRoom(options)`

Opens a clothing-store fitting-room session, as if the player had targeted that shop.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `options` | table \| number | `{ shopId = n }` (index into `Config.shops`), or a bare number/string shop id for legacy callers. Defaults to shop 1 when omitted or not a number. |

**Returns**

- **Nothing. The server re-validates distance and shop policy and opens the session asynchronously; failures surface as a `Kora.notify`/session-error on the client.**

**Example**

```lua
exports.kora_clothing:OpenClothingRoom({ shopId = 3 })
```

**Representative console output**

```text
The numeric form is kept for existing `qb-clothing` consumers; `{ shopId = n }` is the modern form. Does not check the player is actually near shop `n` — that check happens server-side when the session request arrives.
```

### `exports.kora_clothing:OpenWardrobe()`

Opens the player's saved-outfit wardrobe as a normal (paid, cancellable) session over their current skin.

**Parameters**



**Returns**

- **Nothing.**

**Example**

```lua
exports.kora_clothing:OpenWardrobe()
```

**Representative console output**

```text
Equivalent to the legacy `qb-clothing:client:openOutfitMenu` event.
```

### `exports.kora_clothing:reloadSkin()`

Re-applies the citizen's saved skin from the server to the live ped.

**Parameters**



**Returns**

- **Nothing.**

**Example**

```lua
exports.kora_clothing:reloadSkin()
```

**Representative console output**

```text
Same effect as the `/refreshskin` command.
```

### `exports.kora_clothing:IsCreatingCharacter()`

Whether the currently open session is the mandatory first-character creation fitting room.

**Parameters**



**Returns**

- **boolean**

**Example**

```lua
if exports.kora_clothing:IsCreatingCharacter() then return end
```

**Representative console output**

```text
Returns false whenever no session is open, including every other session mode (shop, wardrobe, admin).
```

### `exports.kora_clothing:getOutfits()`

Opens the wardrobe session.

**Parameters**



**Returns**

- **Nothing.**

**Example**

```lua
exports.kora_clothing:getOutfits()
```

**Representative console output**

```text
Despite the name, this does not return outfit data to the caller — it is an alias of `OpenWardrobe` kept for legacy callers that expected this export name. To read outfit data server-side, use the `qb-clothing:server:getOutfits` callback instead (see Legacy protocol).
```

### `exports.kora_clothing:IsClothingMenuOpen()`

Whether any fitting-room session (shop, wardrobe, barber, tattoo, creation, admin) is currently open.

**Parameters**



**Returns**

- **boolean**

**Example**

```lua
if exports.kora_clothing:IsClothingMenuOpen() then return end
```

### `exports.kora_clothing:GetPedModels()`

The two freemode model names this resource recognises.

**Parameters**



**Returns**

- **table** — `{ male = 'mp_m_freemode_01', female = 'mp_f_freemode_01' }` (`Shared.models`).

**Example**

```lua
local models = exports.kora_clothing:GetPedModels()
```

### `exports.kora_clothing:ApplyAppearanceToPed(ped, model, skin)`

Applies this resource's component/prop/tattoo/head schema to an already-created ped that is not the player — a character-select preview clone, for example.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `ped` | number | Entity handle. Must exist and already be the freemode model named by `model`. |
| `model` | string | `'mp_m_freemode_01'` or `'mp_f_freemode_01'`. |
| `skin` | table | A saved/sanitised skin table in this resource's own shape (components, props, head, tattoos, hair). |

**Returns**

- **`true` on success.**
- **`false, 'invalid ped'` when `ped` is not a number, is 0, or does not exist.**
- **`false, 'ped model does not match appearance model'` when `model` is not a recognised freemode name or `ped`'s actual model differs.**

**Example**

```lua
-- Client: paint a saved appearance onto a non-player ped (a character-select clone),
-- never the live player ped.
local ok, err = exports.kora_clothing:ApplyAppearanceToPed(previewPed, model, skin)
if not ok then print(('clothing: could not preview appearance: %s'):format(err)) end
```

**Representative console output**

```text
Never touches `PlayerPedId()` or the session/persistence machinery — it is a pure cosmetic apply onto the ped you pass in.
```

### `exports.kora_clothing:applyStarterAppearance()`

Resets the live player ped to `Config.starterOutfit` for a just-created character and waits for it to be applied. Called by `kora_multichar` before the first spawn of a new character.

**Parameters**



**Returns**

- **`true` once applied.**
- **`false` when a session is already open, `Config.starterOutfit.enabled` is off, the citizen already has a saved appearance (so there is nothing to start from), or the server callback did not answer.**

**Example**

```lua
-- kora_multichar, before the first spawn of a brand-new character:
exports.kora_clothing:applyStarterAppearance()
```

**Representative console output**

```text
Intended for kora_multichar's createCharacter flow rather than general third-party use, but it is a public export like the others.
```

## Additional notes from the code

Because the resource `provide`s `qb-clothing`, scripts written for qb-clothing can also call these exports under `exports['qb-clothing']`.

#### OpenClothingRoom

```lua
exports.kora_clothing:OpenClothingRoom(options)
```

Asks for a `shop` session at a configured shop.

- `options`: `{ shopId = n }` (index in `Config.shops`) or a bare number. Anything else opens shop 1.
- Returns nothing. The server still checks distance, gender lock and downed state, and the player sees any refusal as a notification.

```lua
exports.kora_clothing:OpenClothingRoom({ shopId = 3 }) -- Config.shops[3], Ponsonbys
```

#### OpenWardrobe

```lua
exports.kora_clothing:OpenWardrobe()
```

Opens the personal wardrobe (`wardrobe` mode, `clothing` service, priced). It can be opened anywhere.

#### getOutfits

```lua
exports.kora_clothing:getOutfits()
```

qb-clothing compatibility name. Opens the wardrobe, exactly like `OpenWardrobe`. Job room outfits are not supported.

#### IsClothingMenuOpen

```lua
local open = exports.kora_clothing:IsClothingMenuOpen() -- boolean
```

`true` while any fitting-room session is open on this client.

```lua
if not exports.kora_clothing:IsClothingMenuOpen() then
    exports.kora_clothing:OpenWardrobe()
end
```

#### IsCreatingCharacter

```lua
local creating = exports.kora_clothing:IsCreatingCharacter() -- boolean
```

`true` while the first-character fitting is open.

#### reloadSkin

```lua
exports.kora_clothing:reloadSkin()
```

Loads the saved appearance (`qb-clothing:server:getSkin`) and applies it to the player ped. It does nothing if a session opens before the answer arrives.

#### GetPedModels

```lua
local models = exports.kora_clothing:GetPedModels()
-- { male = 'mp_m_freemode_01', female = 'mp_f_freemode_01' }
```

#### ApplyAppearanceToPed

```lua
local ok, err = exports.kora_clothing:ApplyAppearanceToPed(ped, model, skin)
```

Applies a skin in kora_clothing format (see [Database](../database.md#skin-format)) to an existing ped, for example a local preview clone in a character selector. It does not replace the player ped.

- `ped`: entity handle. `model`: `'mp_m_freemode_01'` or `'mp_f_freemode_01'`, which must match the ped's model. `skin`: skin table.
- Returns `true`, or `false, 'invalid ped'` / `false, 'ped model does not match appearance model'`.
- Drawable and texture indices are checked against the ped before use.

#### applyStarterAppearance

```lua
local applied = exports.kora_clothing:applyStarterAppearance() -- boolean
```

Puts a just-created character into `Config.starterOutfit` (model from `charinfo.gender`) and returns once the ped is dressed. kora_multichar calls it before the first spawn. It returns `false` when a session is open, the starter outfit is disabled, the citizen already has a saved appearance, or the server does not answer. The server callback is rate-limited (6 per 10 seconds).



### Development-only exports

`fftVersion` and `fftAction` (client and server) exist only when the `fft_kora_hooks` convar is `true`, and they accept calls only from the `fft` test runner resource. They are not part of the public API.

## Limits and related APIs

Client only. `OpenClothingRoom`/`OpenWardrobe`/`getOutfits` are asynchronous requests, not synchronous opens — failures (too far from the shop, a session already open) surface as a notify/session-error, not a return value. `ApplyAppearanceToPed` is the only one of these exports meant for a ped other than the live player.

## Related guides

- [Server export](./exports-server.md)
- [Legacy qb-clothing protocol](./legacy-protocol.md)
- [Configuration](./configuration.md)

---
title: Exports
sidebar_position: 5
---

Because the resource `provide`s `qb-clothing`, scripts written for qb-clothing can also call these exports under `exports['qb-clothing']`.

## Client exports

### OpenClothingRoom

```lua
exports.kora_clothing:OpenClothingRoom(options)
```

Asks for a `shop` session at a configured shop.

- `options`: `{ shopId = n }` (index in `Config.shops`) or a bare number. Anything else opens shop 1.
- Returns nothing. The server still checks distance, gender lock and downed state, and the player sees any refusal as a notification.

```lua
exports.kora_clothing:OpenClothingRoom({ shopId = 3 }) -- Config.shops[3], Ponsonbys
```

### OpenWardrobe

```lua
exports.kora_clothing:OpenWardrobe()
```

Opens the personal wardrobe (`wardrobe` mode, `clothing` service, priced). It can be opened anywhere.

### getOutfits

```lua
exports.kora_clothing:getOutfits()
```

qb-clothing compatibility name. Opens the wardrobe, exactly like `OpenWardrobe`. Job room outfits are not supported.

### IsClothingMenuOpen

```lua
local open = exports.kora_clothing:IsClothingMenuOpen() -- boolean
```

`true` while any fitting-room session is open on this client.

```lua
if not exports.kora_clothing:IsClothingMenuOpen() then
    exports.kora_clothing:OpenWardrobe()
end
```

### IsCreatingCharacter

```lua
local creating = exports.kora_clothing:IsCreatingCharacter() -- boolean
```

`true` while the first-character fitting is open.

### reloadSkin

```lua
exports.kora_clothing:reloadSkin()
```

Loads the saved appearance (`qb-clothing:server:getSkin`) and applies it to the player ped. It does nothing if a session opens before the answer arrives.

### GetPedModels

```lua
local models = exports.kora_clothing:GetPedModels()
-- { male = 'mp_m_freemode_01', female = 'mp_f_freemode_01' }
```

### ApplyAppearanceToPed

```lua
local ok, err = exports.kora_clothing:ApplyAppearanceToPed(ped, model, skin)
```

Applies a skin in kora_clothing format (see [Database](./database.md#skin-format)) to an existing ped, for example a local preview clone in a character selector. It does not replace the player ped.

- `ped`: entity handle. `model`: `'mp_m_freemode_01'` or `'mp_f_freemode_01'`, which must match the ped's model. `skin`: skin table.
- Returns `true`, or `false, 'invalid ped'` / `false, 'ped model does not match appearance model'`.
- Drawable and texture indices are checked against the ped before use.

### applyStarterAppearance

```lua
local applied = exports.kora_clothing:applyStarterAppearance() -- boolean
```

Puts a just-created character into `Config.starterOutfit` (model from `charinfo.gender`) and returns once the ped is dressed. kora_multichar calls it before the first spawn. It returns `false` when a session is open, the starter outfit is disabled, the citizen already has a saved appearance, or the server does not answer. The server callback is rate-limited (6 per 10 seconds).

## Server exports

### OpenAdminSession

```lua
local ok, err = exports.kora_clothing:OpenAdminSession(targetSrc, service)
```

Opens a free admin appearance session for another player. **Only the `kora_admin` resource may call it.** For any other caller it returns `false, 'only kora_admin may open a remote admin session'`.

- `targetSrc`: server ID of an online player with a loaded character.
- `service`: `'clothing'`, `'barber'`, `'tattoo'` or `'creation'`. A barber session for a female model uses the hairdresser policy.
- Returns `true`, or `false` with one of: `'target is not online'`, `'that player already has a clothing session open'`, `'invalid appearance service'`.
- Creates a one-use grant valid for 10 seconds and triggers `kora_clothing:client:openAdminSession` on the target.

## Development-only exports

`fftVersion` and `fftAction` (client and server) exist only when the `fft_kora_hooks` convar is `true`, and they accept calls only from the `fft` test runner resource. They are not part of the public API.

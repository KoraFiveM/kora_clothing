---
title: Items
sidebar_position: 8
---

kora_clothing does not need any inventory items by default. The `kora_clothing_outfit` item is used only when `Config.clothingAsItem = true`.

## kora_clothing_outfit

```lua
Config.clothingItem = {
    name = 'kora_clothing_outfit',
    label = 'Outfit',
    weight = 300,
    image = 'kora_clothing_outfit.png',
    description = 'A saved outfit. Use it to put it on.',
}
```

When `Config.clothingAsItem` is on at resource start, the server:

1. waits up to 30 s for kora_core and registers the item with `exports.kora_core:registerShared('items', name, ...)` (`type = 'item'`, `unique = false`, `useable = true`, `shouldClose = true`)
2. waits up to 30 s for kora_inventory and registers the use handler with `exports.kora_inventory:createUseable(name, ...)`

Failures are printed to the server console. You do not need to add the item to a shared items file yourself. The image `kora_clothing_outfit.png` is not included in this resource, so add it to your inventory's image folder.

### How it is given

On a paid confirm (not free shops, character creation or admin sessions), the look is given as an item instead of being saved as the current appearance:

```lua
exports.kora_inventory:addItem(src, 'kora_clothing_outfit', 1, nil, {
    model = model,
    skin = skin,                 -- sanitised skin, see Database
    label = saveName or shopLabel or 'Outfit',
}, 'kora_clothing-purchase')
```

The ped is then reverted to what it wore before the session, and the player sees "Outfit added to your inventory." If kora_inventory is not running or the item does not fit, the look is put on and saved directly instead ("Couldn't fit that in your inventory -- equipped it directly instead."), so a paid purchase is never lost.

### Using it

Using the item sanitises `info.skin` (using `info.model` if it is a freemode model, else the character's default model), saves it to `playerskins` and puts it on through `kora_clothing:client:wearItem`. The item is **not consumed**, so it works like a reusable garment. It is not applied while a fitting-room menu is open.

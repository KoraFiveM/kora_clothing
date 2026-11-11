---
title: Quick toggles
sidebar_position: 6
---

`/c <part>` (the command name is `Config.quickToggle.command`) takes one item off and puts it back without opening a menu. The feature is client-side only (`client/quicktoggle.lua`).

## Parts

| Part | Aliases | What it removes |
| --- | --- | --- |
| `vest` | `kevlar`, `armor`, `armour` | component 9 |
| `shirt` | `top`, `jacket`, `torso` | components 3, 8, 11 (arms, undershirt, top) |
| `pants` | `legs`, `trousers` | component 4 |
| `shoes` | `feet`, `boots` | component 6 |
| `hat` | `helmet`, `cap` | prop 0 |
| `mask` | | component 1 |
| `visor` | | swaps the hat drawable using `Config.quickToggle.visor` |
| `glasses` | `glass`, `shades` | prop 1 |
| `bag` | `backpack` | component 5 |
| `chain` | `neck`, `necklace`, `tie` | component 7 |
| `ears` | `earrings`, `ear` | prop 2 |
| `watch` | | prop 6 |
| `bracelet` | | prop 7 |

`/c reset` or `/c all` (`resetWords`) puts everything back. `/c` on its own, or with an unknown part, shows the usage.

## Behaviour

- Each use **toggles**: the first use removes the item, and the second restores exactly what was worn (drawable, texture, palette).
- **Temporary**: nothing is sent to the server or saved. If the item was changed in the meantime (menu, outfit, another script), the remembered value is dropped instead of being put back over the change.
- Blocked while a fitting-room menu is open ("Close the clothing menu first."). Opening a menu dresses the ped from the saved skin and forgets any remembered toggles.
- Only works on the freemode models.
- `allowDead`, `allowCuffed` (through kora_police's `isHandcuffed` export) and `allowInVehicle` control when the command can be used. `cooldownMs` (default 1500) limits how often.
- A short animation plays per part (`animations`). It does not play in a vehicle unless `animationsInVehicle` is on.
- `visor`: GTA cannot detect visor variants, so `Config.quickToggle.visor` starts empty and players see "This hat has no visor to flip." Add pairs for the helmets in your clothing pack:

```lua
Config.quickToggle.visor = {
    male = { [117] = 118 }, -- example values: hat drawable 117 is the same helmet as 118 with the visor in the other position
    female = {},
}
```

- Gloves are part of the arms (component 3), so `shirt` removes them.
- The same toggles are used by the qb-radialmenu and `qb-clothing:client:adjustfacewear` compatibility events (see [Compatibility](../compatibility.md)).

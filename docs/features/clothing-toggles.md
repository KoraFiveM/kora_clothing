---
title: Preview clothing switches
sidebar_position: 5
---

Menus listed in `Config.ui.clothingToggles.services` (default barber and hairdresser) show four switches on the left, under My Outfits: **Hat**, **Shirt**, **Pants** and **Shoes**. Each one takes that item off the ped and puts it back, so chest hair or a new haircut can be seen. "On" means worn.

- **Preview only.** The change is made on the local ped only. It is never sent to the server, saved or charged. The confirm snapshot always contains the real items.
- The real clothing comes back when the switch is turned on again and whenever the menu closes (confirm, cancel, Esc, going down, resource stop).
- Barbers and hairdressers remove the hat when they open, so the Hat switch starts off there.
- Wearing a saved outfit keeps each switch where it was. Turning a switch back on then puts on the outfit's item.
- Shirt (top, undershirt, arms and gloves), Pants and Shoes use the matching `top`, `legs` and `shoes` part of `Config.tattoo.undress.parts` for the bare look, or the stock freemode values if a part is missing. Hat clears only the hat prop.
- Menus that show these switches always close when the player dies, even with `Config.closeWhenDowned.enabled = false`.

| Option | Default | Meaning |
| --- | --- | --- |
| `Config.ui.clothingToggles.enabled` | `true` | Master switch. |
| `Config.ui.clothingToggles.services` | `{ 'barber', 'hairdresser' }` | Any of `barber`, `hairdresser`, `clothing`, `creation`. The tattoo studio has its own [undress buttons](./tattoos.md#undress-buttons). |
| `Config.ui.clothingToggles.items.hat` / `shirt` / `pants` / `shoes` | `true` | Shows each switch. |

The older `Config.ui.barberTopToggle = false` still hides the Shirt switch.

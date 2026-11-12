---
title: Tattoo studio
sidebar_position: 4
---

Tattoo shops (`service = 'tattoo'`) open a session where only tattoos can change. Character creation and admin sessions also offer tattoos.

## Catalogue

`Config.tattoos` lists base-game overlays:

```lua
{ id = 'business_luxury', label = 'Luxury', group = 'Torso', collection = 'mpbusiness_overlays',
  male = 'MP_Buis_M_Chest_000', female = 'MP_Buis_F_Chest_000', price = 140 },
```

- `id` is what gets saved in the skin's `tattoos` list.
- An entry without an overlay name for a model is hidden for that model.
- The server resolves every submitted ID against the catalogue for the current model and drops unknown ones. Prices from the client are never used.

## Stacking

With `Config.tattoo.allowStacking` (default on), the list has a copy button on applied tattoos that adds another instance of the same tattoo, so it renders darker. Another button removes one instance. The skin repeats the ID once per instance.

- `Config.tattoo.maxStack` (default 3, clamped to 1..10) caps the instances of one tattoo. The server drops any extra.
- `Config.tattoo.stackPriceMultiplier` (default 1.0) scales the price of each instance after the first. Existing instances are never charged again.
- With stacking off, only one instance of each tattoo is kept.

## Undress buttons

The studio previews tattoos on bare skin. With `Config.tattoo.undress.enabled` (default on), a toolbar lets the player remove and put back each part in `Config.tattoo.undress.parts`, plus Undress all and Dress:

| Part | Components (male / female) | Props cleared |
| --- | --- | --- |
| `top` | 3, 8, 11 set to drawable 15 | |
| `legs` | 4 set to 21 / 15 | |
| `shoes` | 6 set to 34 / 35 | |
| `headwear` | 1 set to 0 | 0 (hat), 1 (glasses) |

- Parts in `autoUndressOnOpen` (default `top`, `legs`, `headwear`) start removed. Use an empty list to open fully dressed.
- This is preview only: nothing is sent to the server, saved or charged. The confirm snapshot always reports the clothing the player came in with. The real clothing comes back on confirm, cancel, Esc, death and resource stop.
- A drawable the ped does not have is skipped.
- With `enabled = false`, there are no buttons, and the fixed `Config.tattooStrip` is applied on open (and the hat removed).

With `Config.tattoo.undress.previewInCreator` (default on), choosing a tattoo in character creation or an admin session temporarily removes the part covering its group (Head: headwear, Torso, Arms and Back: top, Legs: legs). Choosing a clothing item for that slot dresses it again.

## Tattoo artist ped

With `Config.tattoo.peds.enabled` (default on), every tattoo shop gets a client-side, frozen artist:

- It is created when the player enters a `scopeRadius` (40 m) sphere around the shop and deleted when they leave. It is placed 1.0 below the shop `coords` (shop coordinates are a standing player's position).
- Model: `shop.tattooPed.model`, else `shop.ped`, else `Config.tattoo.peds.model`. It plays `scenario` (default `WORLD_HUMAN_STAND_IMPATIENT`). Avoid scenarios with a hand prop: only the ped fades, so the prop stays visible.
- In `'target'` interaction mode, the artist gets a "Get tattooed" kora_target option, and the shop's own zone is removed while the artist exists. The zone comes back whenever there is no artist. In `'textui'` mode, the artist is decoration only and the shop opens from the prompt.
- While the studio is open, the artist's opacity is set to `alpha` (default 0) for that player only.
- Changes to `enabled`, `scopeRadius`, `model` and `scenario` rebuild the artists live.
- A decorative `Config.shopPeds` clerk is not spawned at a shop that has an artist.

Per-shop override in `Config.shops`:

```lua
tattooPed = { model = 'u_m_y_tattoo_01', coords = vector4(x, y, z, heading), scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
-- or
tattooPed = false, -- no artist at this shop
```

Keep the artist within a metre or two of the shop zone, because the server only opens a session for players near the zone.

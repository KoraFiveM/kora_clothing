---
title: Troubleshooting
sidebar_position: 10
---

## A shop does not open

- **"Move closer to the ... to open it."** The server only accepts a shop session inside the zone or within `Config.interactDistance + 1` m of it, or within `Config.clothingPointRadius + 1` m of a clothing shop's register or rack point. Check the shop's `zone` or `points` against the map. See [Shops](./features/shops.md#reach-check).
- **No prompt or target at all.** `Config.interactionMode`, `Config.clothingShopPoints`, `Config.clothingPointRadius` and `Config.showTargetHints` are read at start, so restart the resource after changing them. In `'target'` mode, kora_target must be running.
- **"You can't use this while you're down."** `Config.closeWhenDowned.blockOpen` refuses menus during last stand or death.
- **"This barber only serves male characters."** `Config.genderLockedSalons` is on.
- **"Barbers are available to male freemode models only."** The character's saved model is not a freemode model, so no barber or hairdresser policy matches it.
- **"You are not near a ... shop"** comes from `openNearestShop` (kora_admin self-service, or `qb-clothing:client:openMenu` without an argument). It measures from the shop's `coords` or its register and rack points.

## The tattoo artist is missing or misplaced

- The artist exists only while the player is within `Config.tattoo.peds.scopeRadius`. If the model fails to load, the console shows `tattoo artist model ... could not be spawned`, and the shop zone stays in use.
- The artist stands 1.0 below the configured `coords`. Use a standing player's position (as `/coords` reports it).
- In `'textui'` mode the artist has no target option. Use the `[E]` prompt.

## Purchases

- **"You cannot afford this outfit."** (or kora_core's own message): the price is charged from `Config.shop.currency`.
- **"Outfit slots are full."** `Config.wardrobe.maxOutfits` was reached. The look was still put on.
- **"Could not save your outfit. You were not charged."** The database write failed and any charge was refunded.
- With `Config.clothingAsItem`, check the console for item or useable registration errors, and make sure the item image exists in your inventory.

## Appearance after login

- If hair or overlay colours reset after spawn, keep `Config.loginColourReapply.enabled` on, or add a longer delay to `delays`.
- `/refreshskin` applies the saved look again.
- If the saved appearance cannot be loaded when a session opens, the player sees "Could not load your saved appearance. Please try again."

## Quick toggles

- "This hat has no visor to flip.": add visor pairs to `Config.quickToggle.visor`.
- "Close the clothing menu first.": `/c` is blocked while a fitting-room menu is open.
- If another resource already uses `/c`, change `Config.quickToggle.command` and restart.

## Rotation feels wrong

- The cursor leaves the game window: use the default `'capture'` mode instead of `'plain'`.
- The drag never ends: keep `Config.rotateDragGuard` on. `Config.rotateControlsMaxSeconds` always ends a capture or controls drag.
- The arrow stays visible while dragging: keep `Config.rotateHideMethod = 'blank'`.

## Database

The console shows `[kora_clothing:persistence] schema setup failed: ...` or a kora_sql readiness error if the tables could not be created. Fix the database connection for kora_sql and restart.

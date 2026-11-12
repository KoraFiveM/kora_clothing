---
title: "How to use"
sidebar_position: 3
---


# How to use

Players use clothing stores, barbers/hairdressers, the tattoo studio, character creation and their saved outfit wardrobe through one NUI fitting room; every flow shares the same camera, rotate-drag and session-confirm/cancel plumbing. Other resources mostly drive it through `exports.kora_clothing` or the legacy `qb-clothing`/`kora_clothing` net events.

## Shops: clothing, barber, hairdresser, tattoo

1. **Zones** — Each entry in `Config.shops` gets a `kora_target` zone (a polygon traced with `Kora.zones.poly`, or a `{ size, rotation }` box) and, for clothing stores with `points = { register, racks }`, a wide sphere around each of those two points instead (`Config.clothingShopPoints`). `Config.interactionMode` picks `target` (the zone's own target option) or `textui` (default: an `[E] Open <shop>` prompt from `kora_lib`'s TextUI while inside the zone).

2. **Opening** — The client fires `kora_clothing:server:requestSession(mode, extra)` through `Kora.events`'s tokenised events. For a shop, `extra = { shopId = n }`; the server re-checks the player's distance to `Config.shops[n]` (`nearShop`) and the shop's own `service`/`free` policy — the client never supplies those.

3. **Editing** — Only the components/props whitelisted by `Config.services[service]` can change (component 1, the mask slot, is deliberately excluded from the general clothing menu because facial hair uses it). Barbers and hairdressers bare the mask/hat first (`applyTemporaryStrip`) and restore it on close; which head overlays (facial hair, eyebrows, chest hair, make-up, blush, lipstick) are editable there comes from `Config.headOverlays[key].barber`.

4. **Confirming** — `kora_clothing:server:confirmSession` re-reads the citizen's saved skin from the DB (never trusts the session's opening snapshot), merges only the service's allowed fields (`mergeServiceSkin`), prices the diff against `Config.services[service].prices` (plus `Shared.tattooPriceDiff` when the service allows tattoos), charges `Config.shop.currency` through `kora_core`, and only then persists. A confirm that exactly matches an outfit the citizen already owns is never charged again.

5. **Gender-locked salons** — `Config.genderLockedSalons` (off by default): when on, a barber only serves the male freemode model and a hairdresser only the female one; the wrong gender is told to try the other shop. Admin sessions and character creation are unaffected.

## Tattoo studio

Tattoo shops spawn a frozen artist ped (`Config.tattoo.peds`, on by default) that opens the studio when targeted; the shop's own zone prompt is hidden while the artist is present. The studio strips clothing to `Config.tattooStrip` (or, with `Config.tattoo.undress.enabled`, shows Top/Legs/Shoes/Headwear preview buttons the player can toggle) so every catalogue group — Head, Torso, Arms, Back, Legs — is actually visible. A tattoo can be applied more than once to darken it: `Config.tattoo.allowStacking`, `maxStack` (server-enforced) and `stackPriceMultiplier` price every instance beyond the first. All undress/strip changes are preview-only — never sent to the server, never saved, never charged — and the original clothing returns exactly when the menu closes (confirm, cancel, Esc, death, resource stop).

## Character creation and first spawn

- `kora_multichar` calls the client export `applyStarterAppearance()` before the first spawn of a brand-new character. It asks the server callback `kora_clothing:server:getStarterAppearance` (refused for a citizen who already has a saved skin) and resets the ped to `Config.starterOutfit[gender]` — a new character never inherits the previous character's clothes.
- `qb-multicharacter:client:closeNUIdefault` arms a one-shot flag; the mandatory fitting room itself opens once `kora_multichar` signals the real spawn finished (`kora_multichar:client:spawnComplete`, or — for a third-party multichar with no such event — once the ped is alive and active, after a short poll). The event `qb-clothing:client:CreateFirstCharacter` then opens the session (`openSession('firstCharacter')`).
- The first-character session is free, mandatory (cannot be cancelled) and offers every category plus tattoos (`Config.services.creation = { all = true, tattoos = true }`), including heritage (mother/father head blend, `Config.heritage.creator`) if enabled.
- `Config.bucket`: the fitting room runs in a private routing bucket (`Config.bucket.base + source`) so ambient population (and, with `suppressClientPopulation`, this client's own spawned peds/vehicles) does not wander through the creation scene.

## Saved outfits (wardrobe)

Opening the wardrobe (`exports.kora_clothing:OpenWardrobe()` or the legacy `qb-clothing:client:openOutfitMenu` event) is a normal, paid, cancellable session over the citizen's current skin, with the My Outfits list available. Saving a name on confirm inserts a `playeroutfits` row (up to `Config.wardrobe.maxOutfits`, 20 by default); the NUI callbacks `kora_clothing:nui:loadOutfit` and `kora_clothing:nui:deleteOutfit` preview/remove one by id, scoped to the open session's citizen.

## Quick clothing toggle (/c)

`Config.quickToggle` (on by default) registers a chat command (default `/c <part>`, e.g. `/c vest`, `/c hat`, `/c visor`) that takes one clothing part off locally and, on a second use, restores exactly what was worn (drawable, texture, palette). Nothing is sent to the server or saved — opening any fitting-room menu restores everything first, and a change made elsewhere while a part is off is never overwritten. `reset`/`all` put everything back at once.

## Driving it from another resource

Opening the nearest shop of a given service, or previewing a saved appearance on a ped you control (never the live player ped, which the exports below cover separately):

```lua title="example.lua"
-- Server: open the nearest clothing shop/barber/tattoo for a player from another resource
-- (client-side; mirrors what a kora_target zone option does).
TriggerClientEvent('kora_clothing:client:openNearestShop', src, 'tattoo')
```

## Applying an appearance to a non-player ped

Character selectors and similar previews use a local, non-networked ped clone; replacing `PlayerPedId()` would be the wrong operation, so a dedicated export validates the model and applies the skin directly to the ped you pass in.

```lua title="example.lua"
-- Client: paint a saved appearance onto a non-player ped (a character-select clone),
-- never the live player ped.
local ok, err = exports.kora_clothing:ApplyAppearanceToPed(previewPed, model, skin)
if not ok then print(('clothing: could not preview appearance: %s'):format(err)) end
```

---
title: Fitting-room sessions
sidebar_position: 1
---

Every appearance change goes through a **session**. The server keeps one record per player while the menu is open (mode, service, citizen ID, shop, previous routing bucket). That record decides which bucket the player returns to and whether they may cancel. The client's idea of the session is never trusted.

## Modes

| Mode | Opened by | Service | Price |
| --- | --- | --- | --- |
| `shop` | A shop prompt or target, `OpenClothingRoom`, `qb-clothing:client:openMenu`, `kora_clothing:client:openNearestShop` | the shop's `service` | paid, unless the shop has `free = true` |
| `wardrobe` | `OpenWardrobe`, `getOutfits`, `qb-clothing:client:openOutfitMenu` | `clothing` | paid (see below) |
| `firstCharacter` | `qb-clothing:client:CreateFirstCharacter` (fired automatically for new characters) | `creation` | free, mandatory |
| `admin` | `kora_clothing:client:openAdminSession`, or kora_admin through `OpenAdminSession` | the requested service, default `creation` | free |

The wardrobe always uses the `clothing` service. It cannot change hair or tattoos, so it cannot be used to skip a barber or tattoo studio.

A `firstCharacter` request is refused once the citizen already has a saved appearance. This prevents a modified client from reopening the free mandatory fitting.

## Lifecycle

1. The client asks for a session (`kora_clothing:server:requestSession` through kora_lib's tokenised `Kora.events`). If a session is already open, or another request is pending (for up to 30 seconds), the new request is ignored.
2. For shops, the server checks that the player is near the shop (see [Shops](./shops.md#reach-check)). If not, the player gets "Move closer to the ... to open it."
3. The server loads the saved skin, works out the model (saved model, or the model from `charinfo.gender`), applies the barber and hairdresser rules, then moves the player to bucket `Config.bucket.base + source`.
4. The client applies the look, freezes the ped, starts the camera, hides kora_hud (or the radar), and opens the NUI with categories, the hair palette, head controls, tattoos, outfits, money and prices.
5. **Confirm** (`kora_clothing:server:confirmSession`): the server reloads the saved skin, sanitises the requested skin, merges it under the service policy, charges, saves and closes the session.
6. **Cancel** (Cancel button or Esc): the bucket is restored and the ped returns to the look it had when the session opened. The mandatory first-character session cannot be cancelled.

The session also closes when the character logs out (`QBCore:Server:OnPlayerUnload`), on disconnect, and, on the client, when the resource stops. If the client still records a session but no NUI has focus (the menu lost its screen), the next open request cancels the leftover session first.

## Service policy and merging

When a session is confirmed, `mergeServiceSkin` keeps every component or prop the service may not change at its saved value. A modified browser cannot turn a barber visit into a clothing editor. Hair colour follows component 2's allowlist entry, so only services that can change hair can recolour it. Head overlays follow `Config.headOverlays` (see [Hair, head and heritage](./hair-and-head.md)). Skin tone and heritage can only be changed in creation.

### Barbers and hairdressers

Barber and hairdresser are two presentations of one grooming service. By default, the player's freemode model decides which policy is used: female models get `hairdresser` and male models get `barber`, whichever shop they visit. With `Config.genderLockedSalons = true`, shop visits are locked instead. The player is told "This barber only serves male characters. Try a hairdresser." (or the reverse). Admin sessions always follow the model.

On opening, barbers and hairdressers temporarily remove the hat and set the mask to none. These changes are restored on close and are never saved.

## Pricing

Prices are computed only on the server:

- **Categories**: each component and prop belongs to a category (from `shared/components.lua`). The service's `prices` are charged once for each category that changed.

| Category | Components | Props |
| --- | --- | --- |
| `body` | 0 Face, 1 Mask, 2 Hair | |
| `tops` | 3 Arms, 8 Undershirt, 9 Kevlar, 11 Jackets | |
| `legs` | 4 Legs | |
| `shoes` | 6 Shoes | |
| `accessories` | 5 Bag, 7 Accessory, 10 Badge | 0 Hat, 1 Glasses, 2 Ears, 6 Watch, 7 Bracelet |

- **Hair colour and overlays**: a change to the hair colour, highlight, or any head overlay's style, opacity or colour counts as a `body` change.
- **Tattoos** (services with `tattoos = true`): each added instance costs its catalogue price. Instances after the first of the same tattoo are scaled by `Config.tattoo.stackPriceMultiplier`. Removing tattoos and keeping existing ones is free.

No charge is made when:

- the shop has `free = true`, or the mode is `firstCharacter` or `admin`
- the citizen has no `playerskins` row yet (treated as a one-time free sync)
- the confirmed look exactly matches one of the citizen's saved outfits

Money is removed with kora_core `removeMoney(src, Config.shop.currency, price, 'kora_clothing-purchase')`. If the player cannot pay, the session stays open and the error is shown. If saving fails after payment, the amount is refunded (`kora_clothing-persistence-refund`) and the player is told they were not charged.

## Saving outfits

Type a name in "Name this look" before confirming to also save the result as a named outfit (the UI limits it to 40 characters, and the server trims and truncates to 50). When `Config.wardrobe.maxOutfits` is reached, the look is still put on and the player sees "Outfit slots are full." Saved outfits appear in the My Outfits panel, where they can be worn (as a preview inside the session) or deleted.

## Clothing as items

With `Config.clothingAsItem = true`, a paid confirm (not free shops, creation or admin) gives a `kora_clothing_outfit` item instead of saving the look. The ped is then reverted to the previous appearance. If the item cannot be added (kora_inventory not running, inventory full), the look is put on directly and the player is told. See [Items](../items.md).

## First-character fitting

1. kora_core fires `qb-multicharacter:client:closeNUIdefault` only after a character is successfully created.
2. If kora_multichar is running, this only arms the fitting (and starts population suppression). The fitting opens on `kora_multichar:client:spawnComplete` with `isNew = true`, after the ped is placed and the fade-in has finished.
3. With third-party `qb-multicharacter`, the client waits up to 15 seconds for the player to be active and alive, then opens the fitting.
4. kora_multichar can call the `applyStarterAppearance` export before the first spawn so the new character is already wearing `Config.starterOutfit`. The fitting opens on the starter outfit.

## Admin sessions

- `kora_clothing:client:openAdminSession` with an optional service asks for an `admin` session. The server grants it if the player has the kora_core `admin` permission, whatever the client shows.
- kora_admin can open a session for another player with the server export `OpenAdminSession(targetSrc, service)`. Only `kora_admin` may call it. It creates a one-use grant that is valid for 10 seconds, and the target's client then requests the session through the normal token-authenticated path. Accepted services: `clothing`, `barber`, `tattoo`, `creation`. A `barber` grant for a female model is routed to the hairdresser policy.

## Closing when downed

With `Config.closeWhenDowned.enabled`, an open menu is cancelled (preview reverted, NUI closed, camera, focus and HUD restored) when the player:

- enters kora_ambulance's last stand (the `emsDown` player state bag is set), or
- dies (kora_lib cache `isDead` change, or polling every `checkIntervalMs` without the cache module).

The mandatory first-character fitting is never cancelled. With `blockOpen`, menus cannot be opened while downed ("You can't use this while you're down."). With `enabled = false`, a death still closes the tattoo studio and menus that show preview clothing switches.

## Login

The saved skin is applied on `QBCore:Client:OnPlayerLoaded`, when the `kora_core:loggedIn` state bag becomes `true`, and when the resource starts while the player is already logged in. A late answer never overwrites an open session. Colours are then applied again according to `Config.loginColourReapply`.

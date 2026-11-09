# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_clothing — game tests

  @kora_clothing @legacy:cl-start @target:3
  Scenario: Resource starts cleanly
    """
    1. Restart the server and watch the console, or run /server resource kora_clothing.
    2. Join and open F8.
    Expect: kora_clothing starts without errors (no red lines, no missing dependency for kora_theme, kora_target, kora_sql, kora_core). The shop blips and target zones appear on the map without a relog.
    """
    When I manually: restart kora_clothing or watch the server console while it starts
    Then I confirm: kora_clothing starts with no red lines and no missing dependency for kora_theme, kora_target, kora_sql or kora_core
    When I press the "F8" key
    And the F8 console should show no errors
    Then I confirm: the shop blips and target zones appear on the map without a relog

  @kora_clothing @legacy:cl-blips @target:3 @manual
  Scenario: Shop blips and legend
    """
    1. Open the pause map and look at the blips and legend.
    2. Check a clothing, a barber and a tattoo shop.
    Expect: blips for clothing shops (Suburban, Ponsonbys, Binco), barbers/hairdressers and tattoo parlours. The legend groups them as Clothing, Grooming and Tattoo, with the storefront name for clothing (for example Clothing: Ponsonbys). Barber and hairdresser share Grooming.
    """
    When I manually: open the pause map and look at the blips and legend
    Then I confirm: blips exist for clothing shops (Suburban, Ponsonbys, Binco), barbers/hairdressers and tattoo parlours
    When I manually: check a clothing, a barber and a tattoo shop on the map
    Then I confirm: the legend groups them as Clothing, Grooming and Tattoo
    And I confirm: clothing blips show the storefront name, for example Clothing: Ponsonbys
    And I confirm: barber and hairdresser share Grooming

  @kora_clothing @legacy:cl-shop-target @target:3
  Scenario: Clothing shop: target prompt
    """
    1. Walk into a clothing shop (Suburban, Ponsonbys or Binco).
    2. Move around the shop floor, not just the till.
    Expect: the target prompt for the shop shows anywhere inside the store, not only at one spot, and disappears when you step outside. Say which shop and where it failed.
    """
    Given I am at "clothing_shop"
    When I manually: walk around the shop floor, not just the till
    Then I confirm: the shop target prompt shows anywhere inside the store, not only at one spot
    When I manually: step outside the shop
    Then I confirm: the target prompt disappears when I step outside

  @kora_clothing @legacy:cl-shop-open @target:3 @checklist @checklist:kora_clothing:clothing-shops @cat:character-and-ui
  Scenario: Clothing shop: opens the fitting room
    """
    1. Use the shop target prompt.
    Expect: the fitting room menu opens with your ped framed full body, face-on. The HUD hides, other players near you disappear (you are in a private bucket), and you cannot walk away. Your outfit is unchanged until you confirm.
    Also checklist kora_clothing:clothing-shops (Clothing stores (Suburban/Ponsonbys/Binco)): Visit a clothing store blip, use the storefront target; fitting room opens in a private bucket with other players hidden.
    """
    Given I am at "clothing_shop"
    When I manually: use the shop target prompt
    Then I confirm: the fitting room menu opens with my ped framed full body, face-on
    And the HUD should be hidden
    And I confirm: other players near me disappear
    And I confirm: I cannot walk away
    And I confirm: my outfit is unchanged until I confirm

  @kora_clothing @legacy:cl-shop-range @target:3
  Scenario: Shop: too far away is refused
    """
    1. Stand just outside a shop zone (a few metres from the door) and try the target prompt.
    2. Step in and try again.
    Expect: from outside the zone and a metre beyond it, a menu does not open and you get a move closer notice. Inside, it opens normally.
    """
    Given I am at "clothing_shop"
    When I manually: stand just outside the shop zone, a few metres from the door, and try the target prompt
    Then I confirm: no menu opens and I get a move closer notice (also a metre beyond the zone)
    When I manually: step inside the shop and try the target prompt again
    Then I confirm: the menu opens normally

  @kora_clothing @legacy:cl-camera-start @target:3
  Scenario: Camera: starts front-on
    """
    1. Open a clothing shop menu a few times, after turning your ped to different directions.
    Expect: each time the camera opens in front of the ped, face-on, full body, never side-on or behind and never inside a wall.
    """
    Given I am at "clothing_shop"
    When I manually: turn my ped to a different direction and open the clothing shop menu
    And I manually: close the menu and repeat a few times, facing different directions
    Then I confirm: each time the camera opens in front of the ped, face-on and full body
    And I confirm: the camera is never side-on, behind the ped or inside a wall

  @kora_clothing @legacy:cl-camera-presets @target:3
  Scenario: Camera: zone presets
    """
    1. In the menu click each preset button: full, face, torso, legs, shoes.
    Expect: the camera eases (about half a second, no snap) to each framing. Face is centred on the head, shoes on the feet, and the shoes view is never under the ground. Try it with a short and a tall ped model.
    """
    Given I am at "clothing_shop"
    When I manually: open the clothing shop menu
    And I manually: click each preset button in turn: full, face, torso, legs, shoes
    Then I confirm: the camera eases (about half a second, no snap) to each framing
    And I confirm: face is centred on the head and shoes on the feet
    And I confirm: the shoes view is never under the ground
    When I manually: repeat with a short and a tall ped model
    Then I confirm: the framings are correct for both ped models

  @kora_clothing @legacy:cl-camera-zoom @target:3
  Scenario: Camera: mouse wheel zoom
    """
    1. Scroll the mouse wheel with the cursor over the character (not over a menu column).
    2. Click a preset afterwards.
    Expect: the camera zooms smoothly in and out within limits, the menu does not scroll, and picking a preset drops the wheel offset and returns to its normal framing.
    """
    Given I am at "clothing_shop"
    When I manually: open the clothing shop menu
    And I manually: scroll the mouse wheel with the cursor over the character, not over a menu column
    Then I confirm: the camera zooms smoothly in and out within limits
    And I confirm: the menu does not scroll
    When I manually: click a preset
    Then I confirm: the wheel offset is dropped and the camera returns to its normal framing

  @kora_clothing @legacy:cl-camera-wall @target:3
  Scenario: Camera: not blocked by walls or props
    """
    1. Open a small shop (Binco or a tattoo parlour) and zoom out as far as it goes, in each preset.
    Expect: the camera never ends up behind a wall or inside furniture. It fans round to a clear angle or pulls in, and the character is always visible.
    """
    Given I am at "binco_shop"
    When I manually: open the shop menu and zoom out as far as it goes
    And I manually: repeat the zoom out in each preset
    Then I confirm: the camera never ends up behind a wall or inside furniture
    And I confirm: the camera fans round to a clear angle or pulls in
    And I confirm: the character is always visible

  @kora_clothing @legacy:cl-rotate-drag @target:3
  Scenario: Rotate: drag turns the character
    """
    1. Hold the left mouse button over the character and drag left and right.
    2. Repeat with the right mouse button.
    Expect: the character turns with the drag (not the camera), left and right button both work, and the cursor is hidden while you drag.
    """
    Given I am at "clothing_shop"
    When I manually: open the clothing shop menu
    And I manually: hold the left mouse button over the character and drag left and right
    Then I confirm: the character turns with the drag, not the camera
    When I manually: repeat the drag with the right mouse button
    Then I confirm: the right button also turns the character
    And I confirm: the cursor is hidden while I drag

  @kora_clothing @legacy:cl-rotate-edge @target:3
  Scenario: Rotate: drag past the screen edge
    """
    1. Hold the left button and drag very fast and far in one direction.
    Expect: the character keeps turning, the cursor never leaves the game window or reaches a second monitor, and on release the cursor reappears where the drag started.
    """
    Given I am at "clothing_shop"
    When I manually: open the clothing shop menu
    And I manually: hold the left button over the character and drag very fast and far in one direction
    Then I confirm: the character keeps turning
    And I confirm: the cursor never leaves the game window or reaches a second monitor
    When I manually: release the button
    Then I confirm: the cursor reappears where the drag started

  @kora_clothing @legacy:cl-rotate-release @target:3
  Scenario: Rotate: ends on release, blur and Esc
    """
    1. Start a drag, then alt-tab away.
    2. Start a drag and press Esc.
    Expect: the drag always ends, the character stops turning, and the cursor comes back and works normally. After the menu closes the ped faces its original direction again.
    """
    Given I am at "clothing_shop"
    When I manually: open the clothing shop menu
    And I manually: start a drag on the character, then alt-tab away
    Then I confirm: the drag ends, the character stops turning and the cursor works normally
    When I manually: come back to the game, start a drag and press Esc
    Then I confirm: the drag ends, the character stops turning and the cursor works normally
    And I confirm: after the menu closes the ped faces its original direction again

  @kora_clothing @legacy:cl-menu-scroll @target:3
  Scenario: Menu columns scroll with the wheel
    """
    1. Put the cursor over the right-hand menu column and scroll the wheel, then use the arrow keys.
    Expect: the column scrolls smoothly with the wheel and the camera does not zoom. The scrollbar is hidden. Do the same for the left column.
    """
    Given I am at "clothing_shop"
    When I manually: open the clothing shop menu
    And I manually: put the cursor over the right-hand menu column and scroll the wheel, then use the arrow keys
    Then I confirm: the column scrolls smoothly with the wheel and the camera does not zoom
    And I confirm: the scrollbar is hidden
    When I manually: repeat the scrolling over the left column
    Then I confirm: the left column scrolls smoothly, the camera does not zoom and the scrollbar is hidden

  @kora_clothing @legacy:cl-component @target:3
  Scenario: Clothing: change a component
    """
    1. In a clothing shop pick Top and change the style and the texture.
    Expect: the ped changes live. Style and texture can be stepped through without errors or invisible parts, and values past the last one wrap or stop cleanly.
    """
    Given I am at "clothing_shop"
    When I manually: open the clothing shop menu and pick Top
    And I manually: change the style and the texture, stepping past the last value
    Then I confirm: the ped changes live
    And I confirm: style and texture step through without errors or invisible parts
    And I confirm: values past the last one wrap or stop cleanly
    And there should be no script errors

  @kora_clothing @legacy:cl-props @target:3
  Scenario: Props: hat, glasses, ears, watch
    """
    1. Try the hat, glasses, ear and watch/bracelet options and clear each one.
    Expect: each prop appears on the ped and can be removed again. Removing shows the bare ped, with no leftover prop.
    """
    Given I am at "clothing_shop"
    When I manually: open the clothing shop menu
    And I manually: try the hat, glasses, ear and watch/bracelet options and clear each one
    Then I confirm: each prop appears on the ped and can be removed again
    And I confirm: removing shows the bare ped with no leftover prop

  @kora_clothing @legacy:cl-price @target:3
  Scenario: Price shows and is charged
    """
    1. Change one clothing item and look at the total at the bottom.
    2. Confirm and check your cash.
    Expect: a total for the touched category is shown, confirming takes exactly that from cash, and the new outfit stays on. Changing nothing costs nothing.
    """
    Given I am at "clothing_shop"
    And my cash balance is 1000
    When I manually: open the clothing shop menu and change one clothing item
    Then I confirm: a total for the touched category is shown at the bottom
    When I manually: confirm the purchase
    Then I confirm: exactly the shown total is taken from my cash
    And I confirm: the new outfit stays on
    When I manually: open the menu again, change nothing and confirm
    Then my cash balance should have changed by 0

  @kora_clothing @legacy:cl-price-categories @target:3 @manual
  Scenario: Price: only touched categories
    """
    1. Change only hair at a barber, then only an item at a clothing shop, and compare totals.
    Expect: each visit is priced only for the categories (clothing, hair, tattoos) you actually touched, and putting an item back to what you had removes its price.
    """
    When I manually: go to a barber, change only hair and note the total
    And I manually: go to a clothing shop, change only one item and note the total
    Then I confirm: each visit is priced only for the categories (clothing, hair, tattoos) I touched
    When I manually: put the item back to what I had
    Then I confirm: its price is removed from the total

  @kora_clothing @legacy:cl-no-money @target:3 @checklist @checklist:kora_clothing:insufficient-cash @cat:character-and-ui
  Scenario: Not enough money is refused
    """
    1. With less cash than the total (ask an admin to take your cash), pick items and press confirm.
    Expect: the purchase is refused with a clear message, no money goes negative, and the ped is back in the saved outfit when the menu closes.
    Also checklist kora_clothing:insufficient-cash (Not enough cash): Try to confirm a purchase with too little cash; refused with an error and look not saved.
    """
    Given I am at "clothing_shop"
    And my cash balance is 0
    When I manually: open the clothing shop menu, pick items and press confirm
    Then I confirm: the purchase is refused with a clear message
    And my cash balance should be 0
    And I confirm: the ped is back in the saved outfit when the menu closes

  @kora_clothing @legacy:cl-confirm-persist @target:3
  Scenario: Confirm saves the look
    """
    1. Buy a new outfit and confirm.
    2. Disconnect and reconnect, and pick the same character.
    Expect: the new outfit is still on after relogging, and also after /refreshskin.
    """
    Given I am at "clothing_shop"
    And my cash balance is at least 1000
    When I manually: open the clothing shop menu, buy a new outfit and confirm
    And I manually: disconnect, reconnect and pick the same character
    Then I confirm: the new outfit is still on after relogging
    When I run the command "/refreshskin"
    Then I confirm: the new outfit is still on after /refreshskin

  @kora_clothing @legacy:cl-cancel @target:3 @checklist @checklist:kora_clothing:clothing-cancel @cat:character-and-ui
  Scenario: Cancel reverts the look
    """
    1. Change several things, then cancel (or press Esc).
    Expect: the menu closes, the preview is reverted to the saved outfit, nothing is charged, and the camera, cursor, HUD and controls all come back. You can open a shop again straight away.
    Also checklist kora_clothing:clothing-cancel (Cancel restores old look): Change clothes then cancel/Esc; the original appearance is restored and nothing is charged.
    """
    Given I am at "clothing_shop"
    And my cash balance is 500
    When I manually: open the clothing shop menu and change several things
    And I manually: cancel the menu (or press Esc)
    Then I confirm: the menu closes and the preview is reverted to the saved outfit
    And my cash balance should be 500
    And the HUD should be visible
    And I confirm: the camera, cursor and controls all come back
    When I manually: open the shop menu again straight away
    Then I confirm: the menu opens again

  @kora_clothing @legacy:cl-outfit-save @target:3 @checklist @checklist:kora_clothing:wardrobe-save-outfit @cat:character-and-ui
  Scenario: Wardrobe: save an outfit
    """
    1. Change your clothes, enter a name in the save outfit box and confirm.
    Expect: the outfit is saved under that name and shows in My Outfits. A very long or empty name is handled without errors.
    Also checklist kora_clothing:wardrobe-save-outfit (Save outfit to wardrobe): Use 'My Outfits' in a fitting room to save a named outfit (up to 20 per character).
    """
    When I run the command "/testclothing_wardrobe"
    And I manually: change my clothes, enter a name in the save outfit box and confirm
    Then I confirm: the outfit is saved under that name and shows in My Outfits
    When I manually: try saving an outfit with a very long name and then with an empty name
    And the F8 console should show no errors

  @kora_clothing @legacy:cl-outfit-wear @target:3
  Scenario: Wardrobe: wear a saved outfit
    """
    1. Open the wardrobe (outfits menu) and pick a saved outfit.
    Expect: the outfit is applied to the ped, including the model and clothes. Confirming keeps it. Cancelling puts back the previous look.
    """
    When I run the command "/testclothing_wardrobe"
    And I manually: pick a saved outfit in the wardrobe outfits menu
    Then I confirm: the outfit is applied to my ped, including the model and clothes
    When I manually: confirm the outfit
    Then I confirm: the outfit is kept
    When I manually: pick another saved outfit and cancel
    Then I confirm: my previous look is put back

  @kora_clothing @legacy:cl-outfit-delete @target:3
  Scenario: Wardrobe: delete an outfit
    """
    1. In the wardrobe delete a saved outfit.
    Expect: it disappears from the list straight away and stays gone after reopening and after a relog. Other outfits are untouched.
    """
    When I run the command "/testclothing_wardrobe"
    And I manually: delete a saved outfit in the wardrobe
    Then I confirm: the outfit disappears from the list straight away
    When I manually: close and reopen the wardrobe, then relog
    Then I confirm: the deleted outfit stays gone and other outfits are untouched

  @kora_clothing @legacy:cl-outfit-limit @target:3
  Scenario: Wardrobe: outfit limit
    """
    1. Keep saving outfits until you have 20 (ask an admin to change Config.wardrobe.maxOutfits to 2 for a quick test).
    Expect: at the cap saving another is refused with a message, and deleting one makes room again.
    """
    When I run the command "/testclothing_wardrobe"
    And I manually: keep saving outfits until the outfit limit is reached (20 by default, or lower if a Mod changed Config.wardrobe.maxOutfits)
    And I manually: try to save one more outfit
    Then I confirm: saving another outfit at the cap is refused with a message
    When I manually: delete one outfit and save another
    Then I confirm: deleting one made room and the save succeeds

  @kora_clothing @legacy:cl-outfit-per-char @target:3
  Scenario: Outfits belong to one character
    """
    1. Save an outfit on character A.
    2. Relog on character B and open the wardrobe.
    Expect: B does not see A's outfits, and A's still there when you go back.
    """
    When I run the command "/testclothing_wardrobe"
    And I manually: save an outfit on character A
    And I manually: relog on character B and open the wardrobe
    Then I confirm: character B does not see A's outfits
    When I manually: relog back to character A and open the wardrobe
    Then I confirm: A's outfit is still there

  @kora_clothing @legacy:cl-barber @target:3 @checklist @checklist:kora_clothing:barber @cat:character-and-ui @manual
  Scenario: Barber: hair and facial hair
    """
    1. Open a barber (male ped) and change hair style, facial hair, eyebrows and chest hair.
    Expect: each changes live with its own colour box. Only grooming options are offered (no clothes), the price is for hair only, and confirming keeps the cut.
    Also checklist kora_clothing:barber (Barber (hair, facial hair, eyebrows, chest hair)): Use a Barber shop; change hair style/colour, beard, eyebrows, chest hair with colour palettes; confirm and verify saved.
    """
    When I manually: open a barber with a male ped and change hair style, facial hair, eyebrows and chest hair
    Then I confirm: each option changes live with its own colour box
    And I confirm: only grooming options are offered and no clothes
    And I confirm: the price is for hair only
    When I manually: confirm the cut
    Then I confirm: the cut is kept

  @kora_clothing @legacy:cl-hairdresser @target:3 @manual
  Scenario: Hairdresser: hair and make-up
    """
    1. Open a hairdresser with a female ped and change hair style and colour.
    Expect: the hairdresser menu opens, changes show live and are saved on confirm. Either gender can use a barber or hairdresser unless the gender lock is on.
    """
    When I manually: open a hairdresser with a female ped and change hair style and colour
    Then I confirm: the hairdresser menu opens and changes show live
    When I manually: confirm the changes
    Then I confirm: the changes are saved
    And I confirm: either gender can use a barber or hairdresser (only applies when the gender lock is off)

  @kora_clothing @legacy:cl-hair-colour @target:3
  Scenario: Hair colour: primary and highlight
    """
    1. Select the hair item and pick a primary and a secondary colour from the swatches.
    Expect: both colour grids show with the real colours, the ped's hair updates for each, and they are saved after confirm and after a relog. The colour controls only show with hair selected, never in a clothing shop.
    """
    When I manually: open a barber, select the hair item and pick a primary and a secondary colour from the swatches
    Then I confirm: both colour grids show with the real colours
    And I confirm: my ped's hair updates for each colour
    When I manually: confirm and then relog
    Then I confirm: both hair colours are saved after confirm and after the relog
    When I go to "clothing_shop"
    And I manually: open the clothing shop menu
    Then I confirm: the hair colour controls are not shown in the clothing shop

  @kora_clothing @legacy:cl-makeup @target:3 @manual
  Scenario: Make-up, blush and lipstick
    """
    1. In character creation open the make-up, blush and lipstick sections and set a style, opacity and colour for each.
    Expect: each changes live and is saved. They are only offered at barbers if enabled in config, at the hair price.
    """
    When I manually: in character creation open the make-up, blush and lipstick sections and set a style, opacity and colour for each
    Then I confirm: each changes live and is saved
    And I confirm: make-up, blush and lipstick are only offered at barbers when enabled in config, at the hair price (otherwise mark Pass if not offered)

  @kora_clothing @legacy:cl-heritage @target:3 @manual
  Scenario: Heritage in character creation
    """
    1. Create a new character and open Heritage under Face.
    2. Pick a father and a mother, then move the face mix and skin mix.
    Expect: face and skin change live, 0% is all father and 100% all mother, Auto follows the style and skin tone, and it is saved after confirm.
    """
    When I manually: create a new character and open Heritage under Face
    And I manually: pick a father and a mother, then move the face mix and skin mix
    Then I confirm: face and skin change live
    And I confirm: 0% is all father and 100% is all mother
    And I confirm: Auto follows the style and skin tone
    When I manually: confirm the character
    Then I confirm: the heritage is saved after confirm

  @kora_clothing @legacy:cl-toggles @target:3 @checklist @checklist:kora_clothing:barber-preview-toggles @cat:character-and-ui @manual
  Scenario: Barber: preview clothing switches
    """
    1. Open a barber and look at the Hat, Shirt, Pants and Shoes switches under My Outfits.
    2. Turn each off and on.
    Expect: each takes that item off the ped and puts it back, the hat starts off at barbers. Nothing is saved or charged, and the real clothes are back after confirm, cancel or Esc.
    Also checklist kora_clothing:barber-preview-toggles (Preview toggles Hat/Shirt/Pants/Shoes): In barber/hairdresser menu use the 4 left-side switches; items come off on the ped and return on close without being saved.
    """
    When I manually: open a barber and look at the Hat, Shirt, Pants and Shoes switches under My Outfits
    And I manually: turn each switch off and on
    Then I confirm: each switch takes that item off my ped and puts it back
    And I confirm: the hat switch starts off at barbers
    And I confirm: nothing is saved or charged
    When I manually: confirm, cancel or press Esc
    Then I confirm: my real clothes are back after confirm, cancel and Esc

  @kora_clothing @legacy:cl-tattoo-open @target:3
  Scenario: Tattoo studio: artist and menu
    """
    1. Walk toward a tattoo parlour and look for the tattoo artist ped.
    2. Use Get tattooed on the artist.
    Expect: the artist appears as you get near (and goes away when you leave), there is a single Get tattooed option and no second zone prompt, and the studio opens. The artist is hidden for you only while inside.
    """
    When I go to "tattoo_parlour"
    And I manually: walk toward the tattoo parlour and look for the tattoo artist ped
    Then I confirm: the artist appears as I get near
    When I select the "Get tattooed" target option
    Then I confirm: there is a single Get tattooed option and no second zone prompt
    And I confirm: the tattoo studio opens
    And I confirm: the artist is hidden for me only while inside
    When I manually: leave the studio and walk away from the parlour
    Then I confirm: the artist goes away when I leave

  @kora_clothing @legacy:cl-tattoo-apply @target:3 @checklist @checklist:kora_clothing:tattoo-shop @cat:character-and-ui
  Scenario: Tattoo studio: apply and price
    """
    1. Pick a few tattoos from different groups (torso, arms, legs, head).
    2. Check the price and confirm.
    Expect: tattoos show on the right body part for both a male and a female ped, the price matches, and they are still there after a relog.
    Also checklist kora_clothing:tattoo-shop (Tattoo studio): Use a Tattoo Artist target or tattoo ped ('Get tattooed'); browse tattoo list by body group, apply, confirm and pay.
    """
    Given I am at "tattoo_parlour"
    When I manually: open the tattoo studio and pick a few tattoos from torso, arms, legs and head
    And I manually: check the price and confirm
    Then I confirm: tattoos show on the right body part
    And I confirm: the price matches the selection
    When I manually: repeat with a male and a female ped and relog
    Then I confirm: tattoos are right for both genders and still there after the relog

  @kora_clothing @legacy:cl-tattoo-undress @target:3 @checklist @checklist:kora_clothing:tattoo-undress @cat:character-and-ui
  Scenario: Tattoo studio: clothing buttons
    """
    1. In the studio use Top, Legs, Shoes, Hat/mask/glasses and Undress all / Dress.
    2. Confirm, then check your outfit.
    Expect: parts come off and go back, the studio opens with top, legs and head cover bared, and your real clothes are exactly as before on confirm, cancel and Esc.
    Also checklist kora_clothing:tattoo-undress (Tattoo studio clothing buttons): Studio opens with top/legs/hat bared; use the clothing buttons to dress/undress for visibility; real clothes return on close.
    """
    Given I am at "tattoo_parlour"
    When I manually: open the studio and use Top, Legs, Shoes, Hat/mask/glasses and Undress all / Dress
    Then I confirm: parts come off and go back
    And I confirm: the studio opens with top, legs and head cover bared
    When I manually: confirm, then check my outfit
    Then I confirm: my real clothes are exactly as before
    When I manually: reopen the studio and cancel, then reopen and press Esc
    Then I confirm: my clothes are as before after cancel and Esc

  @kora_clothing @legacy:cl-tattoo-stack @target:3 @checklist @checklist:kora_clothing:tattoo-stacking @cat:character-and-ui
  Scenario: Tattoo stacking
    """
    1. Apply a tattoo, then use the copy button to add the same tattoo again, up to the limit.
    Expect: each copy renders darker, more than 3 copies are refused, and extra copies are priced at the stack price. Existing copies are not charged again on a later visit.
    Also checklist kora_clothing:tattoo-stacking (Stack tattoo copies): Use the copy button on an applied tattoo (max 3) to darken it; extra instances charged at the stack multiplier.
    """
    Given I am at "tattoo_parlour"
    When I manually: open the studio, apply a tattoo, then use the copy button to add it again up to the limit
    Then I confirm: each copy renders darker
    And I confirm: more than 3 copies are refused
    And I confirm: extra copies are priced at the stack price
    When I manually: confirm and visit the studio again
    Then I confirm: existing copies are not charged again on the later visit

  @kora_clothing @legacy:cl-tattoo-remove @target:3
  Scenario: Remove a tattoo
    """
    1. Open the studio with tattoos on, remove one and confirm.
    Expect: only that tattoo is gone, the others stay, and it stays removed after a relog.
    """
    Given I am at "tattoo_parlour"
    When I manually: open the studio with tattoos on, remove one tattoo and confirm
    Then I confirm: only that tattoo is gone and the others stay
    When I manually: relog
    Then I confirm: the tattoo stays removed after the relog

  @kora_clothing @legacy:cl-first-char @target:3 @checklist @checklist:kora_clothing:first-character @cat:character-and-ui @manual
  Scenario: First character fitting
    """
    1. Create a brand new character.
    Expect: you spawn first, the fade-in finishes, and only then the free mandatory fitting room opens (not over the spawn scene or mid-teleport). It is free, and the character starts in the starter outfit, not the previous character's clothes.
    Also checklist kora_clothing:first-character (First-character free fitting): Create a new character; mandatory free fitting room opens after spawn completes, with ambient population suppressed.
    """
    When I manually: create a brand new character
    Then I confirm: I spawn first and the fade-in finishes
    And I confirm: only then the fitting room opens, not over the spawn scene or mid-teleport
    And I confirm: the fitting room is free
    And I confirm: the character starts in the starter outfit, not the previous character's clothes

  @kora_clothing @legacy:cl-multichar-preview @target:3 @manual
  Scenario: Character select shows the saved look
    """
    1. Open character select with two characters with different looks.
    Expect: each preview ped wears its own saved look, including hair colour and tattoos, and switching is quick. A character with no saved look still shows a ped.
    """
    When I manually: open character select with two characters with different looks
    Then I confirm: each preview ped wears its own saved look, including hair colour and tattoos
    And I confirm: switching between characters is quick
    And I confirm: a character with no saved look still shows a ped

  @kora_clothing @legacy:cl-login-look @target:3 @checklist @checklist:kora_clothing:login-skin @cat:character-and-ui @manual
  Scenario: Look applies on login
    """
    1. Join with a character with a custom outfit and hair colour.
    Expect: the saved clothes, hair colour and tattoos are on as soon as you are in the world, not default or bald, and without needing /refreshskin.
    Also checklist kora_clothing:login-skin (Saved skin applied on login): Relog or /refreshskin; the saved appearance incl. hair colour is re-applied.
    """
    When I manually: join with a character with a custom outfit and hair colour
    Then I confirm: the saved clothes, hair colour and tattoos are on as soon as I am in the world
    And I confirm: I am not default or bald and did not need /refreshskin

  @kora_clothing @legacy:cl-refreshskin @target:3 @checklist @checklist:kora_clothing:refreshskin @cat:character-and-ui
  Scenario: /refreshskin
    """
    1. Take a piece of clothing off with /c shirt or another script, then type /refreshskin.
    Expect: the saved look is put back on. Using it with no saved look doesn't throw an error.
    Also checklist kora_clothing:refreshskin (/refreshskin command): Run /refreshskin; the saved look is reapplied on your ped.
    """
    When I manually: take a piece of clothing off with /c shirt or another script
    And I run the command "/refreshskin"
    Then I confirm: my saved look is put back on
    When I manually: use /refreshskin on a character with no saved look
    Then there should be no script errors

  @kora_clothing @legacy:cl-quick-toggle @target:3 @checklist @checklist:kora_clothing:quick-toggle @cat:character-and-ui
  Scenario: Quick toggle: /c parts
    """
    1. Type /c shirt, /c pants, /c shoes, /c hat, /c mask, /c glasses, /c vest, /c bag, /c watch, one at a time. Use each twice.
    Expect: the first use takes the item off (with a short animation), the second puts back exactly what you wore. Shirt also removes the undershirt and arms.
    Also checklist kora_clothing:quick-toggle (/c <part> quick clothing toggle): Run /c vest|shirt|pants|shoes|hat|mask|visor|glasses|bag|chain|ears|watch|bracelet; item comes off, repeat puts it back.
    """
    When I run the command "/c shirt"
    Then I should see a notification containing "taken off. Use it again to put it back."
    And I confirm: my shirt comes off with a short animation, including the undershirt and arms
    When I run the command "/c shirt"
    Then I should see a notification containing "put back on."
    And I confirm: my shirt is put back exactly as I wore it
    When I run the command "/c pants"
    Then I should see a notification containing "taken off. Use it again to put it back."
    And I confirm: my pants come off with a short animation
    When I run the command "/c pants"
    Then I should see a notification containing "put back on."
    And I confirm: my pants are put back exactly as before
    When I run the command "/c shoes"
    Then I should see a notification containing "taken off. Use it again to put it back."
    And I confirm: my shoes come off
    When I run the command "/c shoes"
    Then I should see a notification containing "put back on."
    And I confirm: my shoes are put back exactly as before
    When I run the command "/c hat"
    Then I should see a notification containing "taken off. Use it again to put it back."
    And I confirm: my hat comes off
    When I run the command "/c hat"
    Then I should see a notification containing "put back on."
    And I confirm: my hat is put back exactly as before
    When I run the command "/c mask"
    Then I should see a notification containing "taken off. Use it again to put it back."
    And I confirm: my mask comes off
    When I run the command "/c mask"
    Then I should see a notification containing "put back on."
    And I confirm: my mask is put back exactly as before
    When I run the command "/c glasses"
    Then I should see a notification containing "taken off. Use it again to put it back."
    And I confirm: my glasses come off
    When I run the command "/c glasses"
    Then I should see a notification containing "put back on."
    And I confirm: my glasses are put back exactly as before
    When I run the command "/c vest"
    Then I should see a notification containing "taken off. Use it again to put it back."
    And I confirm: my vest comes off
    When I run the command "/c vest"
    Then I should see a notification containing "put back on."
    And I confirm: my vest is put back exactly as before
    When I run the command "/c bag"
    Then I should see a notification containing "taken off. Use it again to put it back."
    And I confirm: my bag comes off
    When I run the command "/c bag"
    Then I should see a notification containing "put back on."
    And I confirm: my bag is put back exactly as before
    When I run the command "/c watch"
    Then I should see a notification containing "taken off. Use it again to put it back."
    And I confirm: my watch comes off
    When I run the command "/c watch"
    Then I should see a notification containing "put back on."
    And I confirm: my watch is put back exactly as before

  @kora_clothing @legacy:cl-quick-reset @target:3 @checklist @checklist:kora_clothing:quick-toggle-reset @cat:character-and-ui
  Scenario: Quick toggle: reset and usage
    """
    1. Take two parts off, then type /c reset (also try /c all).
    2. Type /c on its own and /c nonsense.
    Expect: reset puts everything back. A bare /c or an unknown part shows the usage and the list of parts. The chat suggestion lists the parts.
    Also checklist kora_clothing:quick-toggle-reset (/c reset puts everything back): Remove several parts with /c, then /c reset (or all); all items restored.
    """
    When I run the command "/c hat"
    And I run the command "/c shirt"
    And I run the command "/c reset"
    Then I should see a notification containing "Clothes put back on."
    And I confirm: everything I took off is put back
    When I run the command "/c hat"
    And I run the command "/c shirt"
    And I run the command "/c all"
    Then I confirm: everything is put back
    When I run the command "/c"
    Then I confirm: the usage and the list of parts is shown
    When I run the command "/c nonsense"
    Then I confirm: the usage and the list of parts is shown
    And I confirm: the chat suggestion for /c lists the parts

  @kora_clothing @legacy:cl-quick-limits @target:3 @checklist @checklist:kora_clothing:quick-toggle-blocks @cat:character-and-ui
  Scenario: Quick toggle: cooldown and blocking
    """
    1. Spam /c hat quickly.
    2. Try /c while a fitting-room menu is open, and while dead or cuffed.
    Expect: a short cooldown stops spamming, and /c is blocked in the menu, dead and cuffed. In a vehicle it works without the animation.
    Also checklist kora_clothing:quick-toggle-blocks (Quick toggle restrictions): Try /c while dead, cuffed or with the menu open; refused. Cooldown 1.5s between uses; animation plays on foot.
    """
    When I run the command "/c hat"
    And I run the command "/c hat"
    And I run the command "/c hat"
    And I run the command "/c hat"
    Then I confirm: a short cooldown stops the spamming
    When I manually: open a fitting-room menu and type /c hat
    Then I confirm: /c is blocked while the menu is open
    When I manually: die and type /c hat
    Then I should see a notification containing "You can't use this while you're down."
    And I confirm: /c is blocked while dead
    When I manually: get cuffed by another player and type /c hat
    Then I confirm: /c is blocked while cuffed
    When I manually: sit in a vehicle and type /c hat
    Then I confirm: /c works in a vehicle without the animation

  @kora_clothing @legacy:cl-quick-changed @target:3
  Scenario: Quick toggle forgets changed items
    """
    1. Take your jacket off with /c shirt.
    2. Open a clothing shop, change the top and confirm.
    3. Type /c shirt again.
    Expect: you don't get the old jacket back over your new choice.
    """
    Given I am at "clothing_shop"
    When I run the command "/c shirt"
    And I manually: open the clothing shop, change the top and confirm
    And I run the command "/c shirt"
    Then I confirm: I don't get the old jacket back over my new choice

  @kora_clothing @legacy:cl-privacy @target:3
  Scenario: Fitting room is private
    """
    1. With a second player, have one open a shop menu while the other stands next to them.
    Expect: the second player does not see the first at the shop, the one in the menu does not see anyone, and both are visible again after the menu closes. No ghost ped is left behind.
    """
    Given I am at "clothing_shop"
    When I manually: ask a second player to stand next to me at the shop
    And I manually: open the shop menu
    Then I confirm: the second player does not see me at the shop
    And I confirm: I do not see anyone while in the menu
    When I manually: close the menu
    Then I confirm: both of us are visible again
    And I confirm: no ghost ped is left behind

  @kora_clothing @legacy:cl-population @target:3 @manual
  Scenario: Population in the creation room
    """
    1. Create a new character and look around in the fitting room.
    Expect: no ambient peds or cars in the first-character room. At normal shops the world population stays as usual. Both come back normally when it closes.
    """
    When I manually: create a new character and look around in the fitting room
    Then I confirm: there are no ambient peds or cars in the first-character room
    When I manually: close the fitting room
    Then I confirm: the population comes back normally
    When I manually: open a normal clothing shop
    Then I confirm: the world population stays as usual

  @kora_clothing @legacy:cl-hud @target:3 @checklist @checklist:kora_clothing:hud-hidden @cat:character-and-ui
  Scenario: HUD hides and returns
    """
    1. Open any fitting room and look at the HUD and radar.
    2. Close it by confirm, then by cancel.
    Expect: the HUD and minimap hide while the menu is open and come back exactly as before after confirm, cancel and Esc.
    Also checklist kora_clothing:hud-hidden (HUD and radar hidden in fitting room): While a session is open the HUD/radar is hidden; both return on close.
    """
    Given I am at "clothing_shop"
    When I manually: open the fitting room
    Then the HUD should be hidden
    And the minimap should be hidden
    When I manually: close the menu with confirm
    Then the HUD should be visible
    And the minimap should be visible
    And I confirm: the HUD and minimap are back exactly as before
    When I manually: open the fitting room and close it with cancel
    Then the HUD should be visible
    And the minimap should be visible
    And I confirm: the HUD and minimap are back exactly as before
    When I manually: open the fitting room and close it with Esc
    Then the HUD should be visible
    And the minimap should be visible
    And I confirm: the HUD and minimap are back exactly as before

  @kora_clothing @legacy:cl-downed @target:3
  Scenario: Menu closes when downed
    """
    1. Open a menu, then have an admin kill you or put you in last stand.
    2. Try opening a shop while down.
    Expect: the open menu cancels cleanly (preview reverted, camera, focus and HUD back). Opening while downed or dead is refused with a message.
    """
    Given I am at "clothing_shop"
    When I manually: open a fitting-room menu
    And I manually: ask an admin to kill me or put me in last stand
    Then I confirm: the open menu cancels cleanly with the preview reverted and the camera, focus and HUD back
    When I manually: try opening a shop while down
    Then I should see a notification containing "You can't use this while you're down."
    And I confirm: opening while downed or dead is refused with a message

  @kora_clothing @legacy:cl-stale-session @target:3
  Scenario: Stale menu does not block a shop
    """
    1. Open a shop, then force the NUI to lose focus (alt-tab, or restart kora_theme).
    2. Walk to a shop and open it again.
    Expect: the leftover session is cancelled and the new menu opens, not stuck on a message.
    """
    Given I am at "clothing_shop"
    When I manually: open a shop menu
    And I manually: force the NUI to lose focus by alt-tabbing or restarting kora_theme
    And I manually: walk to a shop and open it again
    Then I confirm: the leftover session is cancelled and the new menu opens, not stuck on a message

  @kora_clothing @legacy:cl-resource-restart @target:3 @needs:admin
  Scenario: Restart the resource while in a menu
    """
    1. Open a shop menu and run /server resource kora_clothing.
    2. Check your ped, camera and cursor, then open a shop again.
    Expect: the ped goes back to the saved look, the camera, cursor, HUD and bucket are restored, and the shop works again with no relog.
    """
    Given I am at "clothing_shop"
    When I manually: open a shop menu
    And I manually: run /server resource kora_clothing
    Then I confirm: my ped goes back to the saved look
    And I confirm: the camera, cursor, HUD and bucket are restored
    And the HUD should be visible
    When I manually: open a shop again
    Then I confirm: the shop works again with no relog

  @kora_clothing @legacy:cl-death-respawn @target:3
  Scenario: Look survives death and respawn
    """
    1. Die (or be revived) and respawn.
    Expect: your clothes, hair and tattoos are the same after respawn and revive, not reset to default.
    """
    When I manually: note my current clothes, hair and tattoos
    And I manually: die and respawn, or be revived
    Then I should be alive
    And I confirm: my clothes, hair and tattoos are the same after respawn and revive, not reset to default

  @kora_clothing @legacy:cl-admin-menu @target:3 @needs:admin @checklist @checklist:kora_clothing:admin-session @cat:character-and-ui
  Scenario: Admin: free clothing, barber, tattoo
    """
    1. As an admin open the kora_admin menu and use the clothing, barber and tattoo entries on yourself.
    2. Use one on another player.
    Expect: a free unrestricted session opens, the target gets it only once, and no money is taken. A non-admin can't open one.
    Also checklist kora_clothing:admin-session (Admin opens clothing for a player): Via kora_admin open a free clothing/barber/tattoo session for another player; it opens once within 10 seconds.
    """
    When I manually: as an admin open the kora_admin menu and use the clothing, barber and tattoo entries on myself
    Then I confirm: a free unrestricted session opens
    And my cash balance should have changed by 0
    When I manually: use one of the entries on another player
    Then I confirm: the target gets the session only once
    And I confirm: no money is taken
    When I manually: ask a non-admin player to try to open one of the sessions
    Then I confirm: the non-admin player can't open one

  @kora_clothing @legacy:cl-admin-denied @target:3 @manual
  Scenario: Non-admin can't open the free session
    """
    1. As a normal player, try to trigger the admin clothing session (kora_admin entries should not show).
    Expect: you can't get a free fitting; if triggered some other way you are refused and nothing changes on the ped.
    """
    When I manually: as a normal player, look for the admin clothing session in kora_admin
    Then I confirm: the kora_admin clothing entries do not show
    And I confirm: I can't get a free fitting
    And I confirm: if triggered some other way I am refused and nothing changes on my ped

  @kora_clothing @legacy:cl-outfit-item @target:3 @checklist @checklist:kora_clothing:clothing-as-item @cat:character-and-ui
  Scenario: Clothing as an item (optional)
    """
    1. Ask an admin to set Config.clothingAsItem = true and restart the resource.
    2. Buy an outfit and open your inventory.
    Expect: an Outfit item is added (no direct equip). Using it puts the outfit on. Skip if you can't change the config.
    Also checklist kora_clothing:clothing-as-item (Outfit as inventory item (optional)): If Config.clothingAsItem is on, a purchase gives a qbclothing_outfit item; using it from inventory equips the look.
    """
    When I manually: buy an outfit at a clothing shop
    And I open my inventory
    Then I confirm: an Outfit item is added and the outfit is not equipped directly (only applies when Config.clothingAsItem is enabled; otherwise mark Pass if nothing happens)
    When I use a "qbclothing_outfit"
    Then I confirm: the outfit is put on (only applies when Config.clothingAsItem is enabled; otherwise mark Pass if nothing happens)

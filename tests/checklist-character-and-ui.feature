# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_clothing — Character & UI

  @kora_clothing @checklist @checklist:kora_clothing:clothing-purchase @cat:character-and-ui
  Scenario: Buy clothing
    """
    Checklist test: Change components/props and confirm; only touched categories are charged to cash and the new look is saved and persists after relog.
    """
    Given I am at "clothing_shop"
    And my cash balance is 1000
    When I manually: open the fitting room and change a component and a prop
    And I manually: confirm the purchase
    Then I confirm: only the touched categories are charged to cash
    And I confirm: the new look is saved
    When I manually: relog
    Then I confirm: the new look persists after relog

  @kora_clothing @checklist @checklist:kora_clothing:hairdresser @cat:character-and-ui
  Scenario: Hairdresser
    """
    Checklist test: Use a Hairdresser shop; options for female styles/colour; hair colour persists after relog.
    """
    Given my cash balance is at least 1000
    When I manually: go to a Hairdresser shop
    And I manually: change the female hair styles and colour
    And I manually: confirm
    And I manually: relog
    Then I confirm: my hair colour persists after relog

  @kora_clothing @checklist @checklist:kora_clothing:camera-orbit @cat:character-and-ui
  Scenario: Fitting-room camera
    """
    Checklist test: Drag to rotate the character, mouse-wheel zoom, switch zone views (full/face/torso/legs/shoes); camera never clips walls.
    """
    Given I am at "clothing_shop"
    When I manually: open the fitting room
    And I manually: drag to rotate the character
    Then I confirm: the character rotates with my drag
    When I manually: scroll the mouse wheel
    Then I confirm: the camera zooms in and out
    When I manually: switch between full, face, torso, legs and shoes views
    Then I confirm: the camera moves to each zone view
    And I confirm: the camera never clips through walls

  @kora_clothing @checklist @checklist:kora_clothing:wardrobe-load-delete @cat:character-and-ui
  Scenario: Load and delete saved outfits
    """
    Checklist test: Open My Outfits / wardrobe, apply a saved outfit, delete one; list updates.
    """
    Given I am at "clothing_shop"
    When I manually: open My Outfits or the wardrobe
    And I manually: apply a saved outfit
    Then I confirm: my ped wears the saved outfit
    When I manually: delete a saved outfit
    Then I confirm: the outfit list updates

  @kora_clothing @checklist @checklist:kora_clothing:gender-locked-salons @cat:character-and-ui @manual
  Scenario: Barber/hairdresser gender rules
    """
    Checklist test: With genderLockedSalons on, barbers serve only male freemode and hairdressers only female models.
    """
    When I manually: try to use a barber with a female freemode model and a hairdresser with a male freemode model
    Then I confirm: barbers serve only male and hairdressers only female models (only applies when Config.genderLockedSalons is enabled; otherwise mark Pass if nothing happens)

  @kora_clothing @checklist @checklist:kora_clothing:qb-compat-events @cat:character-and-ui @needs:admin @manual
  Scenario: qb-clothing compat events and exports
    """
    Checklist test: TriggerEvent qb-clothing:client:openMenu, openOutfitMenu, loadOutfit; exports OpenClothingRoom/OpenWardrobe open the right menus.
    """
    When I manually: as an admin, type /crun TriggerEvent('qb-clothing:client:openMenu') in chat while standing at a clothing shop
    Then I confirm: the clothing menu opens
    When I manually: as an admin, type /crun TriggerEvent('qb-clothing:client:openOutfitMenu') in chat
    Then I confirm: the outfit menu opens
    When I manually: as an admin, type /crun TriggerEvent('qb-clothing:client:loadOutfit', <data of one of my saved outfits>) in chat
    Then I confirm: the saved outfit is applied to my character
    When I manually: as an admin, type /crun exports['kora_clothing']:OpenClothingRoom() in chat
    Then I confirm: the clothing shop menu opens
    When I manually: as an admin, type /crun exports['kora_clothing']:OpenWardrobe() in chat
    Then I confirm: the wardrobe (outfit) menu opens

// Run with `npm test` (node's built-in runner; no extra dependency).
import assert from "node:assert/strict"
import test from "node:test"
import { activeHairSection, enabledOverlays, hairSections, initialSelection, overlayColorEditable, showFaceSkinPanel } from "./panels.ts"
import type { HeadPayload } from "./types.ts"

const head: HeadPayload = {
    skinTone: 0, beard: -1, beardOpacity: 1, beardColor: -1, eyebrows: -1, eyebrowsOpacity: 1, eyebrowsColor: -1,
    chestHair: -1, chestHairOpacity: 1, chestHairColor: -1,
    skinToneEditable: true, overlays: { facialHair: true, eyebrows: true, chestHair: true },
}
const face = { kind: "component", id: 0 }
const mask = { kind: "component", id: 1 }
const hair = { kind: "component", id: 2 }

test("Face & Skin shows only on the Face item", () => {
    assert.equal(showFaceSkinPanel(face, head), true)
    assert.equal(showFaceSkinPanel(mask, head), false)
    assert.equal(showFaceSkinPanel(hair, head), false)
    assert.equal(showFaceSkinPanel(undefined, head), false)
    assert.equal(showFaceSkinPanel({ kind: "prop", id: 0 }, head), false)
})

test("Face & Skin needs an editable skin tone", () => {
    assert.equal(showFaceSkinPanel(face, { ...head, skinToneEditable: false }), false)
    assert.equal(showFaceSkinPanel(face, null), false)
})

test("eyebrows and facial hair show on the Hair item", () => {
    assert.deepEqual(enabledOverlays(hair, head).map((overlay) => overlay.key), ["facialHair", "eyebrows", "chestHair"])
    assert.deepEqual(enabledOverlays(face, head), [])
    assert.deepEqual(enabledOverlays(mask, head), [])
})

test("a category set to false is hidden", () => {
    const noBrows = { ...head, overlays: { facialHair: true, eyebrows: false, chestHair: false } }
    assert.deepEqual(enabledOverlays(hair, noBrows).map((overlay) => overlay.key), ["facialHair"])
    assert.deepEqual(enabledOverlays(hair, { ...head, overlays: { facialHair: false, eyebrows: false, chestHair: false } }), [])
    assert.deepEqual(enabledOverlays(hair, null), [])
})

test("the creator opens on Hair so hair, colour, facial hair and eyebrows show", () => {
    const cats = [
        { kind: "component", id: 11, category: "tops" },
        { kind: "component", id: 0, category: "body" },
        { kind: "component", id: 2, category: "body" },
    ]
    const order = ["tops", "legs", "shoes", "body", "accessories"]
    assert.deepEqual(initialSelection(cats, order, true, undefined), { group: "body", item: cats[2] })
    assert.deepEqual(initialSelection(cats, order, true, false), { group: "tops", item: cats[0] })
    assert.deepEqual(initialSelection(cats, order, false, true), { group: "tops", item: cats[0] })
})

test("an eyebrow palette is offered unless the server locks eyebrows to the hair colour", () => {
    assert.equal(overlayColorEditable(head, "eyebrows"), true)
    assert.equal(overlayColorEditable({ ...head, overlayColors: { facialHair: true, eyebrows: true } }, "eyebrows"), true)
    assert.equal(overlayColorEditable({ ...head, overlayColors: { facialHair: true, eyebrows: false } }, "eyebrows"), false)
    assert.equal(overlayColorEditable({ ...head, overlayColors: { facialHair: true, eyebrows: false } }, "facialHair"), true)
})

test("the Hair item offers Hair plus each allowed overlay as sections", () => {
    const sections = hairSections(enabledOverlays(hair, head))
    assert.deepEqual(sections.map((section) => section.label), ["Hair", "Facial Hair", "Eyebrows", "Chest Hair"])
    assert.deepEqual(hairSections([]), [])
})

test("an unavailable section falls back to Hair", () => {
    const sections = hairSections(enabledOverlays(hair, { ...head, overlays: { facialHair: true, eyebrows: false, chestHair: false } }))
    assert.equal(activeHairSection(sections, "facialHair"), "facialHair")
    assert.equal(activeHairSection(sections, "chestHair"), "hair")
})

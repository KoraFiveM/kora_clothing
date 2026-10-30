// Run with `npm test` (node's built-in runner; no extra dependency).
import assert from "node:assert/strict"
import test from "node:test"
import { enabledOverlays, showFaceSkinPanel } from "./panels.ts"
import type { HeadPayload } from "./types.ts"

const head: HeadPayload = {
    skinTone: 0, beard: -1, beardOpacity: 1, beardColor: -1, eyebrows: -1, eyebrowsOpacity: 1, eyebrowsColor: -1,
    skinToneEditable: true, overlays: { facialHair: true, eyebrows: true },
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
    assert.deepEqual(enabledOverlays(hair, head).map((overlay) => overlay.key), ["facialHair", "eyebrows"])
    assert.deepEqual(enabledOverlays(face, head), [])
    assert.deepEqual(enabledOverlays(mask, head), [])
})

test("a category set to false is hidden", () => {
    const noBrows = { ...head, overlays: { facialHair: true, eyebrows: false } }
    assert.deepEqual(enabledOverlays(hair, noBrows).map((overlay) => overlay.key), ["facialHair"])
    assert.deepEqual(enabledOverlays(hair, { ...head, overlays: { facialHair: false, eyebrows: false } }), [])
    assert.deepEqual(enabledOverlays(hair, null), [])
})

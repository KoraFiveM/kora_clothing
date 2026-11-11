import assert from "node:assert/strict"
import test from "node:test"
import { toggleRequest, togglesFrom } from "./clothingToggles.ts"

test("no switches unless the game sent a list", () => {
    assert.deepEqual(togglesFrom(undefined), [])
    assert.deepEqual(togglesFrom(null), [])
    assert.deepEqual(togglesFrom({}), [])
})

test("the switches keep the game's order and state", () => {
    assert.deepEqual(togglesFrom([{ id: "hat", removed: true }, { id: "shirt", removed: false }, { id: "pants" }, { id: "shoes", removed: "yes" }]), [
        { id: "hat", removed: true },
        { id: "shirt", removed: false },
        { id: "pants", removed: false },
        { id: "shoes", removed: false },
    ])
})

test("unknown or malformed entries are dropped", () => {
    assert.deepEqual(togglesFrom([{ id: "gloves", removed: true }, 4, null, { removed: true }, { id: "shoes", removed: true }]), [
        { id: "shoes", removed: true },
    ])
})

test("flipping a switch asks for the opposite", () => {
    assert.deepEqual(toggleRequest({ id: "shirt", removed: false }), { id: "shirt", removed: true })
    assert.deepEqual(toggleRequest({ id: "hat", removed: true }), { id: "hat", removed: false })
})

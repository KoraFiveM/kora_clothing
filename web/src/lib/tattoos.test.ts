import assert from "node:assert/strict"
import test from "node:test"
import { countOf, duplicateTattoo, instanceLabel, removeTattooInstance, tattooTotal, toggleTattoo } from "./tattoos.ts"

const items = [{ id: "a", label: "Turbulence", group: "Torso", price: 100 }, { id: "b", label: "Anchor", group: "Arms", price: 50 }]
const stacking = { enabled: true, max: 3, priceMultiplier: 1 }

test("duplicate appends another instance of an applied tattoo", () => {
    const next = duplicateTattoo(["a", "b"], "a", stacking)
    assert.deepEqual(next, ["a", "b", "a"])
    assert.equal(countOf(next, "a"), 2)
})

test("duplicate does nothing for a tattoo that is not applied", () => {
    assert.deepEqual(duplicateTattoo(["b"], "a", stacking), ["b"])
})

test("duplicate stops at the max stack", () => {
    let list = ["a"]
    for (let i = 0; i < 5; i++) list = duplicateTattoo(list, "a", stacking)
    assert.deepEqual(list, ["a", "a", "a"])
})

test("stacking disabled keeps a single instance", () => {
    assert.deepEqual(duplicateTattoo(["a"], "a", { enabled: false, max: 3, priceMultiplier: 1 }), ["a"])
})

test("remove takes off one instance and leaves the rest", () => {
    assert.deepEqual(removeTattooInstance(["a", "b", "a", "a"], "a"), ["a", "b", "a"])
    assert.deepEqual(removeTattooInstance(["b"], "a"), ["b"])
})

test("toggle applies one instance or clears every instance", () => {
    assert.deepEqual(toggleTattoo(["b"], "a"), ["b", "a"])
    assert.deepEqual(toggleTattoo(["a", "b", "a"], "a"), ["b"])
})

test("label shows the stack count", () => {
    assert.equal(instanceLabel("Turbulence", 1), "Turbulence")
    assert.equal(instanceLabel("Turbulence", 2), "Turbulence ×2")
})

test("each added instance is priced like a new tattoo; existing ones are free", () => {
    assert.equal(tattooTotal(["a", "a"], ["a"], items, stacking), 100)
    assert.equal(tattooTotal(["a", "a", "b"], [], items, stacking), 250)
    assert.equal(tattooTotal(["a"], ["a", "a"], items, stacking), 0)
    assert.equal(tattooTotal(["a", "a", "a"], ["a"], items, { ...stacking, priceMultiplier: 0.5 }), 100)
})

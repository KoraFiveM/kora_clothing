import assert from "node:assert/strict"
import test from "node:test"
import { toggleTop, topBare, topToggleVisible } from "./topToggle.ts"

test("the button only shows when the game sent it", () => {
    assert.equal(topToggleVisible(undefined), false)
    assert.equal(topToggleVisible(null), false)
    assert.equal(topToggleVisible({ active: false }), true)
})

test("the state is whatever the game reports", () => {
    assert.equal(topBare({ active: true }), true)
    assert.equal(topBare({ active: false }), false)
    assert.equal(topBare({ active: "yes" }), false)
    assert.equal(topBare(undefined), false)
})

test("pressing the button asks for the opposite", () => {
    assert.deepEqual(toggleTop(false), { undressed: true })
    assert.deepEqual(toggleTop(true), { undressed: false })
})

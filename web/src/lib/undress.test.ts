import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import { activeParts, allUndressed, toggleAll, togglePart, undressVisible } from "./undress.ts"

const parts = [{ id: "top", label: "Top" }, { id: "legs", label: "Legs" }]

test("buttons only show when the game sent parts", () => {
    assert.equal(undressVisible(undefined), false)
    assert.equal(undressVisible(null), false)
    assert.equal(undressVisible({ parts: [], active: [] }), false)
    assert.equal(undressVisible({ parts, active: [] }), true)
})

test("a part button bares a dressed part and dresses a bared one", () => {
    assert.deepEqual(togglePart("top", []), { part: "top", undressed: true })
    assert.deepEqual(togglePart("top", ["top"]), { part: "top", undressed: false })
})

test("undress all becomes dress once every part is bare", () => {
    assert.equal(allUndressed(parts, ["top"]), false)
    assert.deepEqual(toggleAll(parts, ["top"]), { part: "all", undressed: true })
    assert.equal(allUndressed(parts, ["top", "legs"]), true)
    assert.deepEqual(toggleAll(parts, ["top", "legs"]), { part: "all", undressed: false })
    assert.equal(allUndressed([], []), false)
})

test("an empty Lua list on the wire reads as nothing bared", () => {
    assert.deepEqual(activeParts({}), [])
    assert.deepEqual(activeParts(undefined), [])
    assert.deepEqual(activeParts(["top", 3, "legs"]), ["top", "legs"])
})

test("the studio wires the buttons to the game callback and resets them per session", () => {
    const app = readFileSync(new URL("../App.tsx", import.meta.url), "utf8")
    assert.match(app, /kora_clothing:nui:setUndress/)
    assert.match(app, /<UndressToolbar/)
    assert.match(app, /setUndressActive\(\[\]\)/)
})

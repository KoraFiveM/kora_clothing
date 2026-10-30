// Guards the right-rail layout: panels must not shrink and the rail must scroll.
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"

const css = readFileSync(new URL("../styles.css", import.meta.url), "utf8")
const rule = (selector: string) => css.split("\n").filter((line) => line.startsWith(`${selector} {`)).join("\n")

test("rail scrolls vertically instead of clipping panels", () => {
    assert.match(rule(".rail"), /overflow-y: auto/)
})

test("rail children never shrink below their content", () => {
    assert.match(rule(".rail > *"), /flex-shrink: 0/)
})

test("colour palette panels keep a bounded height with their own scroll", () => {
    assert.match(rule(".hair-panel"), /max-height: \d+px; overflow: auto/)
})

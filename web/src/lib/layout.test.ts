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

test("rail contains its wheel scrolling", () => {
    assert.match(rule(".rail"), /overscroll-behavior: contain/)
})

test("colour palette panels expand fully with no inner scroll area", () => {
    for (const line of css.split("\n")) {
        if (/\.(hair-panel|head-panel|swatch-block|swatch-grid)\b/.test(line)) {
            assert.doesNotMatch(line, /max-height|overflow\s*:\s*(auto|scroll)/, line)
        }
    }
})

test("the wheel zoom handler lives on the viewport, not on the rail panels", () => {
    const app = readFileSync(new URL("../App.tsx", import.meta.url), "utf8")
    assert.equal(app.match(/onWheel=/g)?.length, 1)
    assert.match(css, /\.rail \{[^}]*pointer-events: none/)
})

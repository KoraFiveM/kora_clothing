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

test("the right rail is the single scroll container, sized to its content", () => {
    const right = rule(".rail-right")
    assert.match(right, /bottom: auto/)
    assert.match(right, /max-height: calc\(100vh - var\(--rail-top\) - var\(--rail-bottom\)\)/)
    assert.match(right, /pointer-events: auto/)
})

test("colour swatches wrap into as many columns as fit", () => {
    assert.match(rule(".swatch-grid"), /repeat\(auto-fill, minmax\(22px, 1fr\)\)/)
})

test("the wheel zoom handler lives on the viewport, not on the rail panels", () => {
    const app = readFileSync(new URL("../App.tsx", import.meta.url), "utf8")
    assert.equal(app.match(/onWheel=/g)?.length, 1)
    assert.match(css, /\.rail \{[^}]*pointer-events: none/)
})

test("UI text is not selectable but inputs stay editable", () => {
    assert.match(css, /#root \*[^}]*user-select: none/)
    assert.match(css, /-webkit-user-select: none/)
    // Same or higher specificity than the blanket rule, or inputs would lose selection.
    assert.match(css, /#root input[^{]*\{[^}]*user-select: text/)
    assert.match(css, /#root textarea/)
    assert.match(css, /\[contenteditable\]/)
})

test("docked rails share one edge inset", () => {
    assert.match(rule(".rail-left"), /left: var\(--edge-inset\)/)
    assert.match(rule(".rail-right"), /right: var\(--edge-inset\)/)
    const inset = /--edge-inset: (\d+)px/g
    for (const [, px] of css.matchAll(inset)) assert.ok(Number(px) >= 16 && Number(px) <= 24, `inset ${px}px`)
})

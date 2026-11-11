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
    assert.doesNotMatch(right, /pointer-events: auto/)
})

test("the rail gutter is click-through and only the panels take pointer events", () => {
    assert.match(rule(".rail"), /pointer-events: none/)
    assert.doesNotMatch(rule(".rail-right"), /pointer-events: auto/)
    assert.match(rule(".panel"), /pointer-events: auto/)
})

test("colour swatches wrap into as many columns as fit", () => {
    assert.match(rule(".swatch-grid"), /repeat\(auto-fill, minmax\(22px, 1fr\)\)/)
})

test("the wheel zoom handler lives on the viewport, not on the rail panels", () => {
    const app = readFileSync(new URL("../App.tsx", import.meta.url), "utf8")
    assert.equal(app.match(/onWheel=/g)?.length, 1)
    assert.match(css, /\.rail \{[^}]*pointer-events: none/)
})

test("the grey scrollbar is hidden unless Config.ui.showScrollbar is on, in old and new Chromium", () => {
    assert.match(css, /\.clothing-shell:not\(\.show-scrollbars\) \.rail \{ scrollbar-width: none; \}/)
    assert.match(css, /\.clothing-shell:not\(\.show-scrollbars\) \.rail::-webkit-scrollbar \{ display: none; width: 0; height: 0; \}/)
})

test("a full-screen overlay holds one cursor for the whole rotate drag", () => {
    assert.match(rule(".drag-overlay"), /position: fixed; inset: 0/)
    assert.match(rule(".drag-overlay"), /cursor: grabbing/)
    assert.match(css, /html\.is-rotating \.drag-overlay \{ display: block; \}/)
    assert.match(css, /html\.is-rotating, html\.is-rotating \* \{ cursor: grabbing !important; \}/)
    assert.match(css, /data-drag-cursor="hidden"\][^{]*\{ cursor: none !important; \}/)
    assert.doesNotMatch(css, /\.clothing-viewport:active/)
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

test("rail shadow gutters hold the full panel shadow on every clipped side", () => {
    const px = (name: string) => Number(new RegExp(`${name}: (\\d+)px`).exec(css)?.[1])
    const y = px("--panel-shadow-y")
    const blur = px("--panel-shadow-blur")
    assert.ok(blur > 0 && y >= 0)
    const inner = px("--shadow-gutter-in")
    const top = px("--shadow-gutter-top")
    const bottom = px("--shadow-gutter-bottom")
    assert.ok(inner >= blur, `side gutter ${inner}px < blur ${blur}px`)
    assert.ok(top >= blur - y, `top gutter ${top}px < ${blur - y}px`)
    assert.ok(bottom >= blur + y, `bottom gutter ${bottom}px < ${blur + y}px`)
    assert.match(rule(".panel"), /box-shadow: 0 var\(--panel-shadow-y\) var\(--panel-shadow-blur\)/)
    // padding and negative margin cancel on all four sides so layout does not move
    const rail = rule(".rail")
    assert.match(rail, /padding: var\(--shadow-gutter-top\) var\(--shadow-gutter-r\) var\(--shadow-gutter-bottom\) var\(--shadow-gutter-l\)/)
    assert.match(rail, /margin: calc\(-1 \* var\(--shadow-gutter-top\)\) calc\(-1 \* var\(--shadow-gutter-r\)\) calc\(-1 \* var\(--shadow-gutter-bottom\)\) calc\(-1 \* var\(--shadow-gutter-l\)\)/)
    // the inner side of the left rail is its right; the right rail's inner side is its left
    assert.match(rule(".rail-left"), /--shadow-gutter-r: var\(--shadow-gutter-in\)/)
    assert.doesNotMatch(rule(".rail-right"), /--shadow-gutter-l/)
})

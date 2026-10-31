import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import { HINT_TIMEOUT_MS, hintEnabled, hintVisible, startHintTimer } from "./hint.ts"

test("the hint is on by default and off only when the server says so", () => {
    assert.equal(hintEnabled({}), true)
    assert.equal(hintEnabled({ showControlsHint: true }), true)
    assert.equal(hintEnabled({ showControlsHint: false }), false)
})

test("visible until dismissed, never when disabled", () => {
    assert.equal(hintVisible(true, false), true)
    assert.equal(hintVisible(true, true), false, "hidden after the first drag or wheel")
    assert.equal(hintVisible(false, false), false, "hidden when the option is off")
})

test("expires after ~8s and the timer can be cancelled", () => {
    let fired = 0
    let delay = 0
    const cancelled: unknown[] = []
    const stop = startHintTimer(() => { fired++ }, (fn, ms) => { delay = ms; fn(); return "h" }, (handle) => cancelled.push(handle))
    assert.equal(delay, HINT_TIMEOUT_MS)
    assert.equal(HINT_TIMEOUT_MS, 8000)
    assert.equal(fired, 1)
    stop()
    assert.deepEqual(cancelled, ["h"])
})

test("the hint never takes pointer events or covers the side panels", () => {
    const css = readFileSync(new URL("../styles.css", import.meta.url), "utf8")
    const rule = css.split("\n").find((line) => line.startsWith(".controls-hint {")) ?? ""
    assert.match(rule, /pointer-events: none/)
    assert.match(rule, /user-select: none/)
    assert.match(css, /\.controls-hint\.is-hidden \{[^}]*opacity: 0/)
})

test("the viewport reports the first rotate drag and wheel to the hint", () => {
    const app = readFileSync(new URL("../App.tsx", import.meta.url), "utf8")
    const viewport = app.slice(app.indexOf("function Viewport"), app.indexOf("function ZoneToolbar"))
    assert.match(viewport, /onWheel=\{[^}]*onInteract\(\)/)
    assert.match(viewport, /onRotate\([^)]*\)\s*\n?\s*onInteract\(\)|onInteract\(\)[^]*onRotate\(/)
})

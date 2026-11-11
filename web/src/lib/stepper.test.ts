import assert from "node:assert/strict"
import test from "node:test"
import { clampStep, parseStepInput, resolveStepEdit } from "./stepper.ts"

const range = { min: 1, max: 215, current: 3 }

test("parses whole numbers and rejects everything else", () => {
    assert.equal(parseStepInput("165"), 165)
    assert.equal(parseStepInput(" 7 "), 7)
    for (const bad of ["", "abc", "1e2", "-3", "1.5", "12a", "0x10"]) assert.equal(parseStepInput(bad), null, bad)
})

test("clamps into the valid range", () => {
    assert.equal(clampStep(0, 1, 215), 1)
    assert.equal(clampStep(999, 1, 215), 215)
    assert.equal(clampStep(165, 1, 215), 165)
})

test("Enter and blur apply a typed value, clamped", () => {
    for (const end of ["enter", "blur"] as const) {
        assert.equal(resolveStepEdit("165", end, range), 165)
        assert.equal(resolveStepEdit("9999", end, range), 215)
        assert.equal(resolveStepEdit("0", end, range), 1)
    }
})

test("Escape reverts whatever was typed", () => {
    assert.equal(resolveStepEdit("165", "escape", range), null)
})

test("non-numeric text reverts instead of applying", () => {
    assert.equal(resolveStepEdit("abc", "enter", range), null)
    assert.equal(resolveStepEdit("", "blur", range), null)
})

test("re-entering the current value sends nothing", () => {
    assert.equal(resolveStepEdit("3", "enter", range), null)
    assert.equal(resolveStepEdit("500", "enter", { min: 1, max: 215, current: 215 }), null)
})

test("a None step lets 0 through", () => {
    assert.equal(resolveStepEdit("0", "enter", { min: 0, max: 40, current: 5 }), 0)
})

test("the typed input keeps its keystrokes away from the menu shortcuts", async () => {
    const { readFileSync } = await import("node:fs")
    const app = readFileSync(new URL("../App.tsx", import.meta.url), "utf8")
    const input = app.slice(app.indexOf("function StepValue"), app.indexOf("function Stepper("))
    assert.match(input, /onKeyDown=\{[^]*event\.stopPropagation\(\)/)
    assert.match(input, /onKeyUp=\{\(event\) => event\.stopPropagation\(\)\}/)
})

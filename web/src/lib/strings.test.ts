import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import { DEFAULT_STRINGS, resolveStrings } from "./strings.ts"

const locale = JSON.parse(readFileSync(new URL("../../../locales/en.json", import.meta.url), "utf8")).ui

test("the UI defaults match locales/en.json", () => {
    assert.deepEqual(DEFAULT_STRINGS, locale)
})

test("the default English says Color, never Colour", () => {
    for (const text of Object.values(locale) as string[]) assert.doesNotMatch(text, /colour/i)
    assert.equal(locale.color, "Color")
})

test("translations from the game replace the defaults", () => {
    const strings = resolveStrings({ color: "Farbe", hair: "Haare" })
    assert.equal(strings.color, "Farbe")
    assert.equal(strings.hair, "Haare")
    assert.equal(strings.opacity, DEFAULT_STRINGS.opacity)
})

test("missing, blank or non-text entries fall back to English", () => {
    assert.deepEqual(resolveStrings(undefined), DEFAULT_STRINGS)
    assert.deepEqual(resolveStrings([]), DEFAULT_STRINGS)
    assert.equal(resolveStrings({ color: "  ", hair: 4, unknown: "x" }).color, "Color")
    assert.equal(resolveStrings({ hair: 4 }).hair, "Hair")
})

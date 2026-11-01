import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import { overRailColumn, scrollRailWithWheel, wheelPixels } from "./railWheel.ts"

const rect = { left: 1000, right: 1288, top: 56, bottom: 900 }
const padding = { left: 20, right: 20, top: 28, bottom: 56 }

test("wheel deltas are normalised to pixels", () => {
    assert.equal(wheelPixels(100, 0, 800), 100)
    assert.equal(wheelPixels(3, 1, 800), 120)
    assert.equal(wheelPixels(1, 2, 800), 800)
})

test("only the visible column counts as over the rail, not the shadow gutter", () => {
    assert.equal(overRailColumn(rect, padding, 1100, 400), true)
    assert.equal(overRailColumn(rect, padding, 1005, 400), false)
    assert.equal(overRailColumn(rect, padding, 1100, 60), false)
    assert.equal(overRailColumn(rect, padding, 1100, 880), false)
    assert.equal(overRailColumn(rect, padding, 200, 400), false)
})

function fakeRail(scrollHeight: number, clientHeight: number) {
    return {
        scrollHeight, clientHeight, scrollTop: 0,
        getBoundingClientRect: () => rect,
    } as unknown as HTMLElement
}
const view = {
    innerHeight: 800,
    getComputedStyle: () => ({ paddingLeft: "20px", paddingRight: "20px", paddingTop: "28px", paddingBottom: "56px" }) as CSSStyleDeclaration,
}

test("a wheel over a gap between panels scrolls the rail", () => {
    const rail = fakeRail(1500, 700)
    assert.equal(scrollRailWithWheel(rail, { clientX: 1100, clientY: 300, deltaY: 100, deltaMode: 0 }, view), true)
    assert.equal(rail.scrollTop, 100)
    scrollRailWithWheel(rail, { clientX: 1100, clientY: 300, deltaY: -40, deltaMode: 0 }, view)
    assert.equal(rail.scrollTop, 60)
})

test("a wheel off the rail, or on a rail with nothing to scroll, is left for the zoom", () => {
    const rail = fakeRail(1500, 700)
    assert.equal(scrollRailWithWheel(rail, { clientX: 300, clientY: 300, deltaY: 100, deltaMode: 0 }, view), false)
    assert.equal(rail.scrollTop, 0)
    assert.equal(scrollRailWithWheel(fakeRail(600, 700), { clientX: 1100, clientY: 300, deltaY: 100, deltaMode: 0 }, view), false)
    assert.equal(scrollRailWithWheel(null, { clientX: 1100, clientY: 300, deltaY: 100, deltaMode: 0 }, view), false)
})

test("the viewport routes wheels through the rail before zooming", () => {
    const app = readFileSync(new URL("../App.tsx", import.meta.url), "utf8")
    assert.match(app, /scrollRailWithWheel\(document\.querySelector<HTMLElement>\("\.rail-right"\), event\)/)
})

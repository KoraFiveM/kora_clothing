import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import { createSmoothScroller, listenForRailWheel, overRailColumn, scrollableRailAt, wheelPixels } from "./railWheel.ts"

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

function fakeRail(scrollHeight: number, clientHeight: number, box = rect) {
    return { scrollHeight, clientHeight, scrollTop: 0, getBoundingClientRect: () => box } as unknown as HTMLElement
}
const view = {
    getComputedStyle: () => ({ paddingLeft: "20px", paddingRight: "20px", paddingTop: "28px", paddingBottom: "56px" }) as CSSStyleDeclaration,
}

test("the column under the pointer is found anywhere over it, panels included", () => {
    const left = fakeRail(1500, 700, { left: 0, right: 288, top: 56, bottom: 900 })
    const right = fakeRail(1500, 700)
    assert.equal(scrollableRailAt([left, right], 1100, 300, view), right)
    assert.equal(scrollableRailAt([left, right], 100, 300, view), left)
    assert.equal(scrollableRailAt([left, right], 600, 300, view), null, "the 3D view between the columns")
    assert.equal(scrollableRailAt([right], 1005, 300, view), null, "the invisible shadow gutter")
    assert.equal(scrollableRailAt([fakeRail(600, 700)], 1100, 300, view), null, "nothing to scroll")
})

function frames() {
    const queue: (() => void)[] = []
    return {
        schedule: (step: () => void) => { queue.push(step) },
        run: (max = 200) => { let n = 0; while (queue.length && n++ < max) queue.shift()!() ; return n },
    }
}

test("a notch glides over a few frames and lands exactly", () => {
    const clock = frames()
    const scroller = createSmoothScroller(clock.schedule)
    const el = { scrollTop: 0, scrollHeight: 1500, clientHeight: 700 }
    scroller.scrollBy(el, 100)
    clock.schedule(() => {}) // a frame passes
    const steps = clock.run()
    assert.equal(el.scrollTop, 100)
    assert.ok(steps > 2, "eased over several frames, not one jump")
})

test("notches mid-glide add up, and the glide stops at either end", () => {
    const clock = frames()
    const scroller = createSmoothScroller(clock.schedule)
    const el = { scrollTop: 0, scrollHeight: 1500, clientHeight: 700 }
    scroller.scrollBy(el, 100)
    scroller.scrollBy(el, 100)
    clock.run()
    assert.equal(el.scrollTop, 200)
    scroller.scrollBy(el, 5000)
    clock.run()
    assert.equal(el.scrollTop, 800, "bottom")
    scroller.scrollBy(el, -5000)
    clock.run()
    assert.equal(el.scrollTop, 0, "top")
})

test("an element that rounds its scroll position still finishes", () => {
    const clock = frames()
    const scroller = createSmoothScroller(clock.schedule)
    let top = 0
    const el = { get scrollTop() { return top }, set scrollTop(value: number) { top = Math.round(value) }, scrollHeight: 1500, clientHeight: 700 }
    scroller.scrollBy(el, 3)
    const steps = clock.run()
    assert.equal(el.scrollTop, 3)
    assert.ok(steps < 200, "no endless frames")
})

test("the window listener scrolls the column and keeps the wheel from the zoom", () => {
    const listeners: Record<string, (event: WheelEvent) => void> = {}
    const queue: (() => void)[] = []
    const rail = fakeRail(1500, 700)
    const win = {
        ...view, innerHeight: 800,
        requestAnimationFrame: (step: () => void) => { queue.push(step) },
        addEventListener: (name: string, fn: (event: WheelEvent) => void) => { listeners[name] = fn },
        removeEventListener: (name: string) => { delete listeners[name] },
    } as unknown as Parameters<typeof listenForRailWheel>[0]
    const stop = listenForRailWheel(win, { querySelectorAll: () => [rail] } as unknown as Document)
    let prevented = 0, stopped = 0
    const wheel = (clientX: number) => ({ clientX, clientY: 300, deltaY: 120, deltaMode: 0, preventDefault: () => { prevented++ }, stopPropagation: () => { stopped++ } }) as unknown as WheelEvent
    listeners.wheel(wheel(1100))
    while (queue.length) queue.shift()!()
    assert.equal(rail.scrollTop, 120)
    assert.equal(prevented, 1)
    assert.equal(stopped, 1)
    listeners.wheel(wheel(500))
    assert.equal(stopped, 1, "a wheel over the 3D view is left for the zoom")
    stop()
    assert.equal(listeners.wheel, undefined)
})

test("App installs the window wheel listener and the viewport no longer scrolls rails itself", () => {
    const app = readFileSync(new URL("../App.tsx", import.meta.url), "utf8")
    assert.match(app, /listenForRailWheel\(window, document\)/)
    assert.doesNotMatch(app, /scrollRailWithWheel/)
})

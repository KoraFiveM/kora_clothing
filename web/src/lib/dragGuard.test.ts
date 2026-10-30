import assert from "node:assert/strict"
import test from "node:test"
import { listenForDragEnd, primaryReleased } from "./dragGuard.ts"

test("a move without the primary button ends the drag", () => {
    assert.equal(primaryReleased({ buttons: 0 }), true)
    assert.equal(primaryReleased({ buttons: 2 }), true)
    assert.equal(primaryReleased({ buttons: 1 }), false)
    assert.equal(primaryReleased({ buttons: 3 }), false)
})

test("blur, mouseleave and a hidden document end the drag; cleanup detaches", () => {
    const win = new EventTarget()
    const doc = Object.assign(new EventTarget(), { visibilityState: "visible" })
    let ends = 0
    const stop = listenForDragEnd(win, doc, () => { ends++ })
    win.dispatchEvent(new Event("blur"))
    doc.dispatchEvent(new Event("mouseleave"))
    assert.equal(ends, 2)
    doc.dispatchEvent(new Event("visibilitychange"))
    assert.equal(ends, 2)
    doc.visibilityState = "hidden"
    doc.dispatchEvent(new Event("visibilitychange"))
    assert.equal(ends, 3)
    stop()
    win.dispatchEvent(new Event("blur"))
    doc.dispatchEvent(new Event("mouseleave"))
    assert.equal(ends, 3)
})

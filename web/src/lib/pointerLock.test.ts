// Run with `npm test` (node's built-in runner; no extra dependency).
import assert from "node:assert/strict"
import test from "node:test"
import { listenForLockChange, listenForLockRelease, releaseRotateLock, requestRotateLock } from "./pointerLock.ts"

test("requests the lock only when enabled", () => {
    let calls = 0
    const element = { requestPointerLock: () => { calls++ } }
    assert.equal(requestRotateLock(element, false), false)
    assert.equal(calls, 0)
    assert.equal(requestRotateLock(element, true), true)
    assert.equal(calls, 1)
})

test("falls back when the lock is unsupported or throws", () => {
    assert.equal(requestRotateLock({}, true), false)
    assert.equal(requestRotateLock({ requestPointerLock: () => { throw new Error("refused") } }, true), false)
})

test("a rejected lock promise does not escape", async () => {
    const element = { requestPointerLock: () => Promise.reject(new Error("refused")) }
    assert.equal(requestRotateLock(element, true), true)
    await new Promise((resolve) => setTimeout(resolve, 0))
})

test("releases the lock and tolerates a missing or throwing exit", () => {
    let exits = 0
    releaseRotateLock({ exitPointerLock: () => { exits++ } })
    assert.equal(exits, 1)
    releaseRotateLock({})
    releaseRotateLock({ exitPointerLock: () => { throw new Error("x") } })
})

test("blur and Escape release, other keys do not, cleanup detaches", () => {
    const target = new EventTarget()
    let releases = 0
    const stop = listenForLockRelease(target, () => { releases++ })
    target.dispatchEvent(Object.assign(new Event("keydown"), { key: "a" }))
    assert.equal(releases, 0)
    target.dispatchEvent(Object.assign(new Event("keydown"), { key: "Escape" }))
    target.dispatchEvent(new Event("blur"))
    assert.equal(releases, 2)
    stop()
    target.dispatchEvent(new Event("blur"))
    assert.equal(releases, 2)
})

test("lock loss reports only when nothing is locked; a refusal reports an error", () => {
    const doc = Object.assign(new EventTarget(), { pointerLockElement: {} as unknown })
    let lost = 0
    let errors = 0
    const stop = listenForLockChange(doc, () => { lost++ }, () => { errors++ })
    doc.dispatchEvent(new Event("pointerlockchange"))
    assert.equal(lost, 0)
    doc.pointerLockElement = null
    doc.dispatchEvent(new Event("pointerlockchange"))
    assert.equal(lost, 1)
    doc.dispatchEvent(new Event("pointerlockerror"))
    assert.equal(errors, 1)
    stop()
    doc.dispatchEvent(new Event("pointerlockchange"))
    doc.dispatchEvent(new Event("pointerlockerror"))
    assert.equal(lost, 1)
    assert.equal(errors, 1)
})

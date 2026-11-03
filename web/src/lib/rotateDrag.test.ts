import assert from "node:assert/strict"
import test from "node:test"
import { RotateDrag, dragCursor, type DragOptions, type RotateMode } from "./rotateDrag.ts"

const W = 1000
const H = 600

function setup(mode: RotateMode, extra: Partial<DragOptions> = {}, accept: boolean | "never" = true) {
    const log = { rotated: [] as number[], ends: 0, recenters: 0, starts: [] as number[][] }
    let resolveStart: (value: boolean) => void = () => {}
    const drag = new RotateDrag({
        rotate: (deg) => log.rotated.push(deg),
        end: () => { log.ends++ },
        recenter: () => { log.recenters++ },
        start: (button, x, y) => {
            log.starts.push([button, x, y])
            if (accept === "never") return new Promise<boolean>((resolve) => { resolveStart = resolve })
            return Promise.resolve(accept)
        },
    }, { mode, degPerPixel: 0.5, guard: true, rightButton: true, ...extra })
    return { drag, log, answer: (value: boolean) => resolveStart(value) }
}
const tick = () => new Promise((resolve) => setTimeout(resolve, 0))
const sample = (clientX: number, movementX = 0, buttons = 1) => ({ clientX, clientY: 300, movementX, buttons, width: W, height: H })

test("plain drag rotates by movementX and ends once on release", () => {
    const { drag, log } = setup("plain")
    assert.equal(drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H }), true)
    drag.move(sample(510, 10))
    drag.move(sample(490, -20))
    assert.deepEqual(log.rotated, [-5, 10])
    drag.up()
    drag.up()
    assert.equal(log.ends, 1)
    assert.equal(drag.dragging, false)
})

test("only the left button, and the right one when enabled, start a drag", () => {
    const a = setup("plain")
    assert.equal(a.drag.down({ button: 1, clientX: 1, clientY: 1, width: W, height: H }), false)
    assert.equal(a.drag.down({ button: 2, clientX: 1, clientY: 1, width: W, height: H }), true)
    const b = setup("plain", { rightButton: false })
    assert.equal(b.drag.down({ button: 2, clientX: 1, clientY: 1, width: W, height: H }), false)
})

test("a right-button drag ends when the right button is no longer held", () => {
    const { drag, log } = setup("plain")
    drag.down({ button: 2, clientX: 500, clientY: 300, width: W, height: H })
    drag.move(sample(510, 10, 2))
    assert.equal(log.rotated.length, 1)
    drag.move(sample(520, 10, 0))
    assert.equal(drag.dragging, false)
    assert.equal(log.ends, 1)
    drag.move(sample(530, 10, 2))
    assert.equal(log.rotated.length, 1)
})

test("lost() ends a cursor drag only when the guard is on", () => {
    const on = setup("plain")
    on.drag.down({ button: 0, clientX: 5, clientY: 5, width: W, height: H })
    on.drag.lost()
    assert.equal(on.log.ends, 1)
    const off = setup("plain", { guard: false })
    off.drag.down({ button: 0, clientX: 5, clientY: 5, width: W, height: H })
    off.drag.lost()
    assert.equal(off.drag.dragging, true)
    off.drag.cancel()
    assert.equal(off.drag.dragging, false)
    assert.equal(off.log.ends, 0)
})

test("recenter: asks near an edge once and ignores the jump to the centre", () => {
    const { drag, log } = setup("recenter")
    drag.down({ button: 0, clientX: 300, clientY: 300, width: W, height: H })
    drag.move(sample(200)) // -100px -> +50deg
    drag.move(sample(100)) // -100px -> +50deg
    drag.move(sample(30))  // inside the edge margin: asks to recentre
    assert.equal(log.recenters, 1)
    drag.move(sample(20))  // still waiting for the jump: no second request
    assert.equal(log.recenters, 1)
    const before = log.rotated.length
    drag.move(sample(500)) // the synthetic jump to the centre
    assert.equal(log.rotated.length, before, "jump adds no rotation")
    drag.move(sample(520)) // real movement continues from the new centre
    assert.equal(log.rotated[log.rotated.length - 1], -10)
    assert.deepEqual(log.rotated.slice(0, 4), [50, 50, 35, 5])
})

test("recenter: nothing happens until the cursor is really at the edge", () => {
    const { drag, log } = setup("recenter")
    drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H })
    for (const x of [400, 300, 200, 100, 70]) drag.move(sample(x)) // 7% from the edge: still fine
    assert.equal(log.recenters, 0)
    drag.move(sample(30))
    assert.equal(log.recenters, 1)
})

test("recenter: edgeMargin option is honoured", () => {
    const { drag, log } = setup("recenter", { edgeMargin: 0.2 })
    drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H })
    drag.move(sample(150))
    assert.equal(log.recenters, 1)
})

test("recenter: asks again if the jump never arrives", () => {
    const { drag, log } = setup("recenter")
    drag.down({ button: 0, clientX: 100, clientY: 300, width: W, height: H })
    drag.move(sample(30))
    assert.equal(log.recenters, 1)
    for (let i = 0; i < 40; i++) drag.move(sample(30 - (i % 2)))
    assert.ok(log.recenters >= 2)
})

test("recenter: a big real move that does not land at the centre is not swallowed", () => {
    const { drag, log } = setup("recenter")
    drag.down({ button: 0, clientX: 100, clientY: 300, width: W, height: H })
    drag.move(sample(30))
    assert.equal(log.recenters, 1)
    drag.move(sample(700)) // large, but not near the centre
    assert.equal(log.rotated[log.rotated.length - 1], -335)
})

test("controls: hands the drag to Lua and ignores blur and pointer events afterwards", async () => {
    const { drag, log } = setup("controls")
    drag.down({ button: 0, clientX: 250, clientY: 150, width: W, height: H })
    assert.deepEqual(log.starts, [[0, 0.25, 0.25]])
    await tick()
    assert.equal(drag.handedToLua, true)
    drag.lost() // the cursorless focus switch blurs the page
    drag.move(sample(10, 5, 0))
    assert.equal(drag.dragging, true)
    assert.deepEqual(log.rotated, [])
    assert.equal(log.ends, 0)
    drag.luaStopped()
    assert.equal(drag.dragging, false)
    assert.equal(log.ends, 0, "Lua ended it, so no rotateEnd is sent back")
})

test("controls: Escape, close or release while Lua owns the drag tell Lua to stop", async () => {
    const { drag, log } = setup("controls")
    drag.down({ button: 0, clientX: 1, clientY: 1, width: W, height: H })
    await tick()
    drag.cancel()
    assert.equal(log.ends, 1)
    assert.equal(drag.dragging, false)
})

test("controls: declined by Lua falls back to a plain drag", async () => {
    const { drag, log } = setup("controls", {}, false)
    drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H })
    await tick()
    assert.equal(drag.handedToLua, false)
    drag.move(sample(510, 10))
    assert.deepEqual(log.rotated, [-5])
    drag.up()
    assert.equal(log.ends, 1)
})

test("controls: releasing before Lua answers stops the drag Lua then starts", async () => {
    const { drag, log, answer } = setup("controls", {}, "never")
    drag.down({ button: 0, clientX: 1, clientY: 1, width: W, height: H })
    drag.up()
    assert.equal(log.ends, 1)
    answer(true)
    await tick()
    assert.equal(log.ends, 2, "late accept is followed by an end")
    assert.equal(drag.dragging, false)
})

test("controls: a blur while waiting does not end a drag Lua then accepts, but ends a declined one", async () => {
    const a = setup("controls", {}, "never")
    a.drag.down({ button: 0, clientX: 1, clientY: 1, width: W, height: H })
    a.drag.lost()
    assert.equal(a.drag.dragging, true)
    a.answer(true)
    await tick()
    assert.equal(a.drag.handedToLua, true)
    const b = setup("controls", {}, "never")
    b.drag.down({ button: 0, clientX: 1, clientY: 1, width: W, height: H })
    b.drag.lost()
    b.answer(false)
    await tick()
    assert.equal(b.drag.dragging, false)
})

test("controls: a rejected start request falls back to the plain drag", async () => {
    const log = { rotated: [] as number[] }
    const drag = new RotateDrag({
        rotate: (deg) => log.rotated.push(deg), end: () => {}, recenter: () => {},
        start: () => Promise.reject(new Error("no")),
    }, { mode: "controls", degPerPixel: 1, guard: true, rightButton: true })
    drag.down({ button: 0, clientX: 1, clientY: 1, width: W, height: H })
    await tick()
    drag.move(sample(2, 3))
    assert.deepEqual(log.rotated, [-3])
})

test("capture: Lua takes the drag, pointer moves (and its pulls) turn nothing, the release tells Lua", async () => {
    const { drag, log } = setup("capture")
    drag.down({ button: 0, clientX: 250, clientY: 150, width: W, height: H })
    assert.deepEqual(log.starts, [[0, 0.25, 0.25]])
    drag.move(sample(600, 350)) // the first pull lands before Lua's answer: not the hand
    assert.deepEqual(log.rotated, [])
    await tick()
    assert.equal(drag.handedToLua, true)
    drag.move(sample(510, 10))
    drag.move(sample(500, -10))
    assert.deepEqual(log.rotated, [], "Lua turns the camera, the NUI adds nothing")
    drag.lost() // a lost capture or leave is not the release; Lua keeps the cursor in the window
    assert.equal(drag.dragging, true)
    drag.up()
    assert.equal(drag.dragging, false)
    assert.equal(log.ends, 1, "rotateEnd sent so Lua stops and puts the cursor back")
})

test("capture: a move that reports the button up ends it, so does a window blur", async () => {
    const { drag, log } = setup("capture")
    drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H })
    await tick()
    drag.move(sample(500, 0, 0))
    assert.equal(drag.dragging, false)
    assert.equal(log.ends, 1)
    drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H })
    await tick()
    drag.lost(true)
    assert.equal(drag.dragging, false)
    assert.equal(log.ends, 2)
})

test("capture: a blur while Lua is answering ends the drag it then starts", async () => {
    const { drag, log, answer } = setup("capture", {}, "never")
    drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H })
    drag.lost(true)
    assert.equal(drag.dragging, true)
    answer(true)
    await tick()
    assert.equal(drag.dragging, false)
    assert.equal(log.ends, 1)
})

test("capture: declined by Lua carries on by recentring near the edge", async () => {
    const { drag, log } = setup("capture", {}, false)
    drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H })
    await tick()
    assert.equal(drag.handedToLua, false)
    drag.move(sample(500))
    drag.move(sample(980))
    assert.deepEqual(log.rotated, [-240])
    assert.equal(log.recenters, 1, "asked Lua to recentre near the edge")
    drag.move(sample(500)) // the recentre jump
    assert.deepEqual(log.rotated, [-240], "the jump is ignored")
    drag.up()
    assert.equal(log.ends, 1)
})

test("a refused pointer lock falls back to recentring near the edge and ignores the jump", () => {
    const { drag, log } = setup("pointer")
    drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H })
    drag.useRecenter()
    drag.move(sample(480, -20)) // first move after the switch only sets the baseline
    drag.move(sample(470, -10))
    assert.deepEqual(log.rotated, [5])
    drag.move(sample(10, -460))
    assert.equal(log.recenters, 1)
    drag.move(sample(500, 490))
    assert.equal(log.rotated.length, 2)
    drag.up()
    assert.equal(log.ends, 1)
})

test("useRecenter does nothing without a running drag", () => {
    const { drag, log } = setup("pointer")
    drag.useRecenter()
    drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H })
    drag.move(sample(510, 10))
    assert.deepEqual(log.rotated, [-5])
})

test("only a plain drag may show the cursor; every mode that moves it hides it", () => {
    assert.equal(dragCursor("plain", "grabbing"), "hidden", "hidden by default")
    assert.equal(dragCursor("plain", "grabbing", false), "grabbing")
    assert.equal(dragCursor("plain", "hidden", false), "hidden")
    for (const mode of ["capture", "recenter", "pointer", "controls"] as const) {
        assert.equal(dragCursor(mode, "grabbing"), "hidden", mode)
    }
})

test("plain: a long drag sends only movementX turns, never a recentre or a Lua start", async () => {
    const { drag, log } = setup("plain")
    drag.down({ button: 0, clientX: 500, clientY: 300, width: W, height: H })
    await tick()
    for (let x = 500; x < 990; x += 10) drag.move({ clientX: x, clientY: 300, movementX: 10, buttons: 1, width: W, height: H })
    assert.equal(log.recenters, 0)
    assert.deepEqual(log.starts, [])
    assert.equal(log.rotated.length, 49)
    drag.up()
    assert.equal(log.ends, 1)
})

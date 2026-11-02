// The drag-to-rotate state machine, kept free of React and the DOM so the ways a
// drag can start, move and end are testable.
//
// Modes (Config.rotateMode):
//   plain     (default) a normal cursor drag turning the camera from movementX; the
//             cursor is never moved, so it cannot flicker. Also what pointer becomes
//             when Config.rotatePointerLock is off.
//   capture   Lua owns the drag once it accepts rotateStart, as in
//             controls, but NUI focus and the cursor never change: Lua reads the
//             cursor every frame and pulls it back to the centre itself. The NUI
//             ignores pointer moves meanwhile (they include those pulls), still sees
//             the release, and tells Lua. Declined, the drag carries on as recenter.
//   controls  Lua owns the drag once it accepts rotateStart: the cursor is hidden
//             and the mouse is read as a game control, so the NUI sees no more
//             pointer events and must not treat the resulting blur as the end.
//   recenter  a normal cursor drag; near a screen edge Lua is asked to move the
//             cursor back to the centre, and that synthetic jump is ignored.
//   pointer   a normal cursor drag using movementX (pointer lock itself is requested
//             by the caller). When the lock is refused the caller calls useRecenter()
//             and the drag carries on as recenter.

export type RotateMode = "capture" | "controls" | "recenter" | "pointer" | "plain"

/** The cursor a drag shows. Only a plain drag leaves the cursor alone, so only it can
 * honour Config.rotateDragCursor; every other mode moves the cursor itself (or hands
 * the mouse to the game), and a visible cursor that gets moved flickers. */
export function dragCursor(mode: RotateMode, configured: "grabbing" | "hidden"): "grabbing" | "hidden" {
    return mode === "plain" ? configured : "hidden"
}

export interface DragIO {
    /** Degrees to add to the orbit (already scaled). */
    rotate(deltaDeg: number): void
    /** The drag is over; Lua settles the camera and gives focus back. */
    end(): void
    /** controls mode: ask Lua to take the drag. Resolves true when it did. */
    start(button: number, x: number, y: number): Promise<boolean>
    /** recenter mode: ask Lua to put the cursor back at the screen centre. */
    recenter(): void
}

export interface DragOptions {
    mode: RotateMode
    degPerPixel: number
    /** Config.rotateDragGuard: blur / leave / lost capture end the drag. */
    guard: boolean
    rightButton: boolean
    /** Fraction of the screen from an edge at which recenter asks for a recentre. */
    edgeMargin?: number
}

export interface PointerSample {
    button?: number
    buttons?: number
    movementX?: number
    clientX: number
    clientY: number
    width: number
    height: number
}

const WAIT_LIMIT = 30 // moves to wait for a recentre jump before asking again

/** Which bit of PointerEvent.buttons belongs to a PointerEvent.button. */
function buttonBit(button: number): number {
    return button === 2 ? 2 : 1
}

export class RotateDrag {
    private active = false
    private button = 0
    private luaOwned = false
    private pending = false
    private lostWhilePending = false
    private token = 0
    private lastX = 0
    private lastY = 0
    private awaitingCenter = false
    private waited = 0
    private recenterFallback = false
    private resync = false

    private readonly io: DragIO
    private opts: DragOptions

    constructor(io: DragIO, opts: DragOptions) {
        this.io = io
        this.opts = opts
    }

    setOptions(opts: DragOptions) { this.opts = opts }
    get dragging() { return this.active }
    /** Lua is reading the mouse; no pointer events are expected until it stops. */
    get handedToLua() { return this.active && this.luaOwned }

    /** Returns true when a drag began. */
    down(sample: PointerSample): boolean {
        const button = sample.button ?? 0
        if (this.active) return false
        if (button !== 0 && !(button === 2 && this.opts.rightButton)) return false
        this.active = true
        this.button = button
        this.luaOwned = false
        this.lostWhilePending = false
        this.awaitingCenter = false
        this.waited = 0
        this.recenterFallback = false
        this.resync = false
        this.lastX = sample.clientX
        this.lastY = sample.clientY
        const token = ++this.token
        if (this.opts.mode === "controls" || this.opts.mode === "capture") {
            this.pending = true
            this.io.start(button, sample.clientX / Math.max(1, sample.width), sample.clientY / Math.max(1, sample.height))
                .catch(() => false)
                .then((accepted) => this.accepted(token, accepted))
        }
        return true
    }

    private accepted(token: number, accepted: boolean) {
        if (token !== this.token) {
            // The drag was over (or replaced) before Lua answered: stop what it started.
            if (accepted) this.io.end()
            return
        }
        this.pending = false
        if (!this.active) { if (accepted) this.io.end(); return }
        if (accepted) {
            this.luaOwned = true
            // Capture never switches focus, so a blur while waiting was real.
            if (this.opts.mode === "capture" && this.lostWhilePending) this.finish()
            return
        }
        // Declined: keep the plain drag (capture recentres instead), unless the window was lost meanwhile.
        if (this.opts.mode === "capture") { this.recenterFallback = true; this.resync = true }
        if (this.lostWhilePending) this.finish()
    }

    /** The pointer lock was refused or lost to the game: finish this drag by moving
     * the cursor back to the centre near an edge instead of using movementX. */
    useRecenter() {
        if (!this.active || this.luaOwned || this.opts.mode === "recenter") return
        this.recenterFallback = true
        this.resync = true
        this.awaitingCenter = false
    }

    /** Returns true when the sample turned the camera. */
    move(sample: PointerSample): boolean {
        if (!this.active) return false
        const captured = this.opts.mode === "capture" && (this.luaOwned || this.pending)
        if (this.luaOwned && !captured) return false
        // The button came up somewhere we could not see.
        if (this.opts.guard && sample.buttons !== undefined && (sample.buttons & buttonBit(this.button)) === 0) {
            this.finish()
            return false
        }
        // Lua turns the camera from the cursor and its own pulls move it: nothing to add here.
        if (captured) return false
        if (this.opts.mode !== "recenter" && !this.recenterFallback) {
            const delta = sample.movementX ?? 0
            if (delta === 0) return false
            this.io.rotate(-delta * this.opts.degPerPixel)
            return true
        }
        return this.moveRecenter(sample)
    }

    private moveRecenter(sample: PointerSample): boolean {
        const { clientX: x, clientY: y, width, height } = sample
        if (this.resync) { this.lastX = x; this.lastY = y; this.resync = false }
        if (this.awaitingCenter) {
            const nearCenter = Math.abs(x - width / 2) <= width * 0.1 && Math.abs(y - height / 2) <= height * 0.1
            const jumped = Math.abs(x - this.lastX) > width * 0.2 || Math.abs(y - this.lastY) > height * 0.2
            if (nearCenter && jumped) {
                // The synthetic jump from our own recentre, not the player's hand.
                this.lastX = x
                this.lastY = y
                this.awaitingCenter = false
                return false
            }
            if (++this.waited > WAIT_LIMIT) this.awaitingCenter = false
        }
        const dx = x - this.lastX
        this.lastX = x
        this.lastY = y
        let turned = false
        if (dx !== 0) { this.io.rotate(-dx * this.opts.degPerPixel); turned = true }
        const margin = this.opts.edgeMargin ?? 0.04
        const nearEdge = x < width * margin || x > width * (1 - margin) || y < height * margin || y > height * (1 - margin)
        if (nearEdge && !this.awaitingCenter) {
            this.awaitingCenter = true
            this.waited = 0
            this.io.recenter()
        }
        return turned
    }

    /** Button released over the viewport. */
    up() { this.finish() }

    /** Blur, the cursor left the window, capture lost: only honoured with the guard on
     * (or forced, for blur). A controls drag ignores them (the focus switch itself
     * causes a blur); a capture drag only ends on a real window blur (forced). */
    lost(force = false) {
        if (!this.active || (!this.opts.guard && !force)) return
        if (this.luaOwned && (this.opts.mode === "controls" || !force)) return
        if (this.pending) { this.lostWhilePending = true; return }
        this.finish()
    }

    /** Escape, menu close, unmount: always ends the drag. */
    cancel() { this.finish() }

    /** Lua ended the drag itself (button released, safety stop). */
    luaStopped() {
        this.active = false
        this.luaOwned = false
        this.pending = false
        this.token++
    }

    private finish() {
        const wasActive = this.active
        const wasLua = this.luaOwned || this.pending
        this.active = false
        this.luaOwned = false
        this.pending = false
        this.awaitingCenter = false
        this.token++
        if (wasActive && (this.opts.guard || wasLua)) this.io.end()
    }
}

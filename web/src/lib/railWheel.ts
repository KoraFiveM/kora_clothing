// The menu columns (.rail) are click-through: pointer-events: none, with only
// their panels taking input, so a drag or wheel in the gaps reaches the 3D view.
// In FiveM's NUI a wheel over a panel then never scrolls the column it sits in
// (the scroller itself is not hit-testable), which left the arrow keys as the
// only way to move the right-hand menu. So the wheel is handled here, once, at
// the window: anywhere over a column that can scroll, it scrolls that column,
// and it never reaches the camera zoom.

export interface Box { left: number; right: number; top: number; bottom: number }

/** Wheel deltas arrive in pixels, lines or pages depending on the input. */
export function wheelPixels(deltaY: number, deltaMode: number, pageHeight: number) {
    if (deltaMode === 1) return deltaY * 40
    if (deltaMode === 2) return deltaY * pageHeight
    return deltaY
}

/** Whether the point is over the visible rail column: its border box minus the
 * shadow-gutter padding, which is invisible and belongs to the 3D view. */
export function overRailColumn(rect: Box, padding: Box, x: number, y: number) {
    return x >= rect.left + padding.left && x <= rect.right - padding.right
        && y >= rect.top + padding.top && y <= rect.bottom - padding.bottom
}

interface StyleView { getComputedStyle: (el: Element) => CSSStyleDeclaration }

/** The column under the point that has something to scroll, or null. */
export function scrollableRailAt(rails: Iterable<HTMLElement>, x: number, y: number, view: StyleView = window): HTMLElement | null {
    for (const rail of rails) {
        if (rail.scrollHeight <= rail.clientHeight) continue
        const style = view.getComputedStyle(rail)
        const padding = {
            left: parseFloat(style.paddingLeft) || 0, right: parseFloat(style.paddingRight) || 0,
            top: parseFloat(style.paddingTop) || 0, bottom: parseFloat(style.paddingBottom) || 0,
        }
        if (overRailColumn(rail.getBoundingClientRect(), padding, x, y)) return rail
    }
    return null
}

interface Scrollable { scrollTop: number; scrollHeight: number; clientHeight: number }

/** Glides each wheel notch over a few frames instead of jumping a whole notch at
 * once; notches that arrive mid-glide add to where it is heading. */
export function createSmoothScroller(schedule: (step: () => void) => unknown, ease = 0.35) {
    const goals = new Map<Scrollable, number>()
    const limit = (el: Scrollable, value: number) => Math.min(Math.max(0, el.scrollHeight - el.clientHeight), Math.max(0, value))
    const step = () => {
        for (const [el, goal] of goals) {
            const to = limit(el, goal)
            const before = el.scrollTop
            const remaining = to - before
            if (Math.abs(remaining) < 1) { el.scrollTop = to; goals.delete(el); continue }
            const move = Math.abs(remaining * ease) < 1 ? Math.sign(remaining) : remaining * ease
            el.scrollTop = before + move
            // Rounded away or already at its end: finish rather than spin.
            if (el.scrollTop === before) { el.scrollTop = to; goals.delete(el) }
        }
        if (goals.size > 0) schedule(step)
    }
    return {
        scrollBy(el: Scrollable, delta: number) {
            const idle = goals.size === 0
            goals.set(el, limit(el, (goals.get(el) ?? el.scrollTop) + delta))
            if (idle) schedule(step)
        },
    }
}

interface WheelHost extends StyleView {
    innerHeight: number
    requestAnimationFrame: (step: () => void) => unknown
    addEventListener: Window["addEventListener"]
    removeEventListener: Window["removeEventListener"]
}

/** Scrolls whichever menu column the wheel is over, from anywhere over it. Runs
 * in the capture phase so neither a panel nor the viewport's zoom sees those
 * wheels. Returns the cleanup function. */
export function listenForRailWheel(win: WheelHost, doc: Pick<Document, "querySelectorAll">): () => void {
    const scroller = createSmoothScroller((step) => win.requestAnimationFrame(step))
    const onWheel = (event: WheelEvent) => {
        const rail = scrollableRailAt(doc.querySelectorAll<HTMLElement>(".rail"), event.clientX, event.clientY, win)
        if (!rail) return
        event.preventDefault()
        event.stopPropagation()
        scroller.scrollBy(rail, wheelPixels(event.deltaY, event.deltaMode, win.innerHeight))
    }
    win.addEventListener("wheel", onWheel, { capture: true, passive: false })
    return () => win.removeEventListener("wheel", onWheel, { capture: true })
}

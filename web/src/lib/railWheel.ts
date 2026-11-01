// The right rail is click-through (pointer-events: none, only its panels take
// input), so the browser hit-tests a wheel over the 10px gaps between panels,
// and over the rail edges, to the 3D viewport underneath and the camera zooms
// instead of the menu scrolling. The viewport hands those wheels back here.

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

/** Scrolls the rail by the wheel and returns true when it took the event. False
 * when the pointer is outside the column or the rail has nothing to scroll, so
 * the wheel zooms the camera as before. */
export function scrollRailWithWheel(
    rail: HTMLElement | null,
    event: { clientX: number; clientY: number; deltaY: number; deltaMode: number },
    view: { getComputedStyle: (el: Element) => CSSStyleDeclaration; innerHeight: number } = window,
) {
    if (!rail || rail.scrollHeight <= rail.clientHeight) return false
    const style = view.getComputedStyle(rail)
    const padding = {
        left: parseFloat(style.paddingLeft) || 0, right: parseFloat(style.paddingRight) || 0,
        top: parseFloat(style.paddingTop) || 0, bottom: parseFloat(style.paddingBottom) || 0,
    }
    if (!overRailColumn(rail.getBoundingClientRect(), padding, event.clientX, event.clientY)) return false
    rail.scrollTop += wheelPixels(event.deltaY, event.deltaMode, view.innerHeight)
    return true
}

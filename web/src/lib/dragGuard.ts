// A rotate drag must end whenever the browser can no longer tell us the button
// came up: the cursor left the game window, focus was lost, or the pointer
// capture was taken away. Without this the "dragging" flag sticks and the
// camera keeps spinning until the player clicks again.

/** True when a move event reports the primary button is no longer held. */
export function primaryReleased(event: { buttons: number }): boolean {
    return (event.buttons & 1) === 0
}

/** Calls onEnd when the window blurs, the document is left with no button held, or hidden. Returns the cleanup function. */
export function listenForDragEnd(win: EventTarget, doc: EventTarget & { visibilityState?: string; pointerLockElement?: unknown }, onEnd: () => void): () => void {
    const onVisibility = () => { if (doc.visibilityState === "hidden") onEnd() }
    win.addEventListener("blur", onEnd)
    // A locked pointer never leaves the window; some browsers still report a leave.
    // A held button keeps delivering moves outside the window, so leaving it is not an
    // end by itself; the drag ends on release or when a move reports no button.
    const onLeave = (event: Event) => { if (!doc.pointerLockElement && ((event as { buttons?: number }).buttons ?? 0) === 0) onEnd() }
    doc.addEventListener("mouseleave", onLeave)
    doc.addEventListener("visibilitychange", onVisibility)
    return () => {
        win.removeEventListener("blur", onEnd)
        doc.removeEventListener("mouseleave", onLeave)
        doc.removeEventListener("visibilitychange", onVisibility)
    }
}

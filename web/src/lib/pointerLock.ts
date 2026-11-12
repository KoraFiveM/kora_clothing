// Pointer lock keeps the cursor from leaving the screen while the player drags
// to rotate. It only adds to the normal pointer-capture drag, so when the lock
// is refused the drag still works exactly as before.

interface LockableElement {
    requestPointerLock?: () => unknown
}

interface LockDocument {
    exitPointerLock?: () => void
}

/** Returns false when the lock is off, unsupported or refused (sync or async). */
export function requestRotateLock(element: LockableElement, enabled: boolean): boolean {
    if (!enabled || typeof element.requestPointerLock !== "function") return false
    try {
        const result = element.requestPointerLock()
        // Newer CEF returns a promise that rejects when the lock is refused.
        if (result && typeof (result as Promise<void>).catch === "function") (result as Promise<void>).catch(() => {})
        return true
    } catch {
        return false
    }
}

export function releaseRotateLock(doc: LockDocument) {
    try { doc.exitPointerLock?.() } catch { /* nothing locked */ }
}

/** Calls onRelease on window blur and Escape. Returns the cleanup function. */
export function listenForLockRelease(target: EventTarget, onRelease: () => void): () => void {
    const onKey = (event: Event) => { if ((event as KeyboardEvent).key === "Escape") onRelease() }
    target.addEventListener("blur", onRelease)
    target.addEventListener("keydown", onKey)
    return () => {
        target.removeEventListener("blur", onRelease)
        target.removeEventListener("keydown", onKey)
    }
}

interface LockEvents extends EventTarget {
    pointerLockElement?: unknown
}

/**
 * Watches the lock itself. onLost runs when the lock is gone (pointerlockchange
 * with nothing locked: Escape, alt-tab, the game took the mouse back); onError
 * runs when the request was refused, so the caller keeps the plain drag.
 * Returns the cleanup function.
 */
export function listenForLockChange(doc: LockEvents, onLost: () => void, onError: () => void): () => void {
    const onChange = () => { if (!doc.pointerLockElement) onLost() }
    doc.addEventListener("pointerlockchange", onChange)
    doc.addEventListener("pointerlockerror", onError)
    return () => {
        doc.removeEventListener("pointerlockchange", onChange)
        doc.removeEventListener("pointerlockerror", onError)
    }
}

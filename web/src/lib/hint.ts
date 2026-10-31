// The "Drag to rotate · Scroll to zoom" hint: shown when a menu opens, gone after
// the first rotate drag or wheel zoom, or after HINT_TIMEOUT_MS, or never when
// Config.ui.showControlsHint is off.

export const HINT_TIMEOUT_MS = 8000

/** The server sends the option on every open; a payload without it keeps the default (on). */
export function hintEnabled(payload: { showControlsHint?: boolean }): boolean {
    return payload.showControlsHint !== false
}

export function hintVisible(enabled: boolean, dismissed: boolean): boolean {
    return enabled && !dismissed
}

/** Calls `onExpire` after the timeout. Returns the cancel function. */
export function startHintTimer(
    onExpire: () => void,
    schedule: (fn: () => void, ms: number) => unknown = (fn, ms) => setTimeout(fn, ms),
    cancel: (handle: unknown) => void = (handle) => clearTimeout(handle as ReturnType<typeof setTimeout>),
): () => void {
    const handle = schedule(onExpire, HINT_TIMEOUT_MS)
    return () => cancel(handle)
}

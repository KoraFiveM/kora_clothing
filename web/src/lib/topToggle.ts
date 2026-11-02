// Barber / hairdresser shirt button. Like the tattoo undress buttons, the game
// owns the truth (whether the top is actually off the ped); the UI sends a
// request and shows what the reply says, and nothing here reaches the saved outfit.

export interface TopTogglePayload {
    active: boolean
}

export interface SetTopPayload {
    undressed: boolean
}

export interface SetTopResponse {
    ok: boolean
    active?: boolean
}

/** Absent means this session has no shirt button (not a barber, or Config.ui.barberTopToggle is off). */
export function topToggleVisible(payload: TopTogglePayload | null | undefined): payload is TopTogglePayload {
    return !!payload && typeof payload === "object"
}

export function topBare(payload: { active?: unknown } | null | undefined): boolean {
    return payload?.active === true
}

/** The request for the button: take the top off unless it already is. */
export function toggleTop(bare: boolean): SetTopPayload {
    return { undressed: !bare }
}

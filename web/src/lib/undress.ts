// Tattoo studio clothing buttons. The game owns the truth (which parts are
// actually bared on the ped); the UI only sends a request and shows what the
// reply says is active, so a refused or partial request can never leave a
// button lying.

export interface UndressPart {
    id: string
    label: string
}

export interface UndressPayload {
    parts: UndressPart[]
    active: string[]
}

export interface SetUndressPayload {
    /** A part id, or "all". */
    part: string
    undressed: boolean
}

export interface SetUndressResponse {
    ok: boolean
    active?: string[]
}

/** Absent or empty means this session has no buttons (not a tattoo studio, or Config.tattoo.undress is off). */
export function undressVisible(payload: UndressPayload | null | undefined): payload is UndressPayload {
    return !!payload && Array.isArray(payload.parts) && payload.parts.length > 0
}

/** The wire form of an empty Lua list can arrive as an object; anything that is not an array of strings is "nothing bared". */
export function activeParts(value: unknown): string[] {
    return Array.isArray(value) ? value.filter((id): id is string => typeof id === "string") : []
}

export function allUndressed(parts: UndressPart[], active: string[]): boolean {
    return parts.length > 0 && parts.every((part) => active.includes(part.id))
}

/** The request for one part's button: bare it unless it already is. */
export function togglePart(part: string, active: string[]): SetUndressPayload {
    return { part, undressed: !active.includes(part) }
}

/** The request for the "Undress all / Dress" button. */
export function toggleAll(parts: UndressPart[], active: string[]): SetUndressPayload {
    return { part: "all", undressed: !allUndressed(parts, active) }
}

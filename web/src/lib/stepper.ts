// Typed entry for the "n / max" steppers. Kept free of React so the rules can be
// tested directly: the component only forwards what the player did.

export type StepEnd = "enter" | "blur" | "escape"

export interface StepRange {
    /** Lowest value the player can type, 1-based as displayed (0 where "None" is allowed). */
    min: number
    /** Highest value, 1-based as displayed. */
    max: number
    /** The value currently shown. */
    current: number
}

/** Whole numbers only: "12" parses, "1e2", "-3", "1.5" and "" do not. */
export function parseStepInput(raw: string): number | null {
    const text = raw.trim()
    return /^\d{1,6}$/.test(text) ? Number(text) : null
}

export function clampStep(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value))
}

/** What committing a typed value should do. Returns the clamped value to apply,
 * or null to leave things as they were: Escape reverts, non-numeric text
 * reverts, and re-entering the current value changes nothing. */
export function resolveStepEdit(raw: string, end: StepEnd, range: StepRange): number | null {
    if (end === "escape") return null
    const parsed = parseStepInput(raw)
    if (parsed === null) return null
    const next = clampStep(parsed, range.min, range.max)
    return next === range.current ? null : next
}

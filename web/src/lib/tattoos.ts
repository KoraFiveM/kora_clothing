/** Tattoo stacking: the selection is an ordered list of tattoo ids, one entry
 * per applied instance, so a stacked tattoo is the same id repeated. */
import type { TattooItem, TattooStacking } from "./types.ts"

export const DEFAULT_STACKING: TattooStacking = { enabled: true, max: 3, priceMultiplier: 1 }

export function stackLimit(stacking?: TattooStacking | null): number {
    const s = stacking ?? DEFAULT_STACKING
    return s.enabled ? Math.max(1, s.max) : 1
}

export function countOf(selected: string[], id: string): number {
    let count = 0
    for (const value of selected) if (value === id) count++
    return count
}

/** The copy button: appends another instance of an applied tattoo, up to the limit. */
export function duplicateTattoo(selected: string[], id: string, stacking?: TattooStacking | null): string[] {
    const count = countOf(selected, id)
    if (count === 0 || count >= stackLimit(stacking)) return selected
    return [...selected, id]
}

/** Removes one instance of a tattoo (the last one), leaving the others in place. */
export function removeTattooInstance(selected: string[], id: string): string[] {
    const index = selected.lastIndexOf(id)
    if (index < 0) return selected
    return [...selected.slice(0, index), ...selected.slice(index + 1)]
}

/** The checkbox: applies a first instance, or clears every instance. */
export function toggleTattoo(selected: string[], id: string): string[] {
    return countOf(selected, id) > 0 ? selected.filter((value) => value !== id) : [...selected, id]
}

/** "Turbulence" for one instance, "Turbulence ×2" for a stack. */
export function instanceLabel(label: string, count: number): string {
    return count > 1 ? `${label} ×${count}` : label
}

/** Price of one more instance given how many are already applied. */
export function instancePrice(price: number, instance: number, stacking?: TattooStacking | null): number {
    if (instance <= 1) return price
    return Math.floor(price * (stacking ?? DEFAULT_STACKING).priceMultiplier + 0.5)
}

/** Mirrors the server: instances beyond what was already owned are charged,
 * removals and existing instances are free. */
export function tattooTotal(selected: string[], baseline: string[], items: TattooItem[], stacking?: TattooStacking | null): number {
    let total = 0
    for (const item of items) {
        const before = countOf(baseline, item.id)
        const after = countOf(selected, item.id)
        for (let instance = before + 1; instance <= after; instance++) total += instancePrice(item.price, instance, stacking)
    }
    return total
}

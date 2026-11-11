// Preview clothing switches under My Outfits (Config.ui.clothingToggles). Like
// the tattoo undress buttons, the game owns the truth -- whether the item is
// actually off the ped -- so the UI sends a request and shows the state the
// reply reports. Nothing here reaches the saved outfit.

export type ClothingToggleId = "hat" | "shirt" | "pants" | "shoes"

const TOGGLE_IDS: readonly ClothingToggleId[] = ["hat", "shirt", "pants", "shoes"]

export interface ClothingToggle {
    id: ClothingToggleId
    /** True while the item is off the ped for the preview. */
    removed: boolean
}

export interface SetClothingTogglePayload {
    id: ClothingToggleId
    removed: boolean
}

export interface SetClothingToggleResponse {
    ok: boolean
    toggles?: unknown
}

/** The switches the game sent, in its order. Unknown ids and malformed entries
 * are dropped; anything that is not a list means the menu has none. */
export function togglesFrom(raw: unknown): ClothingToggle[] {
    if (!Array.isArray(raw)) return []
    const list: ClothingToggle[] = []
    for (const entry of raw) {
        if (!entry || typeof entry !== "object") continue
        const { id, removed } = entry as { id?: unknown; removed?: unknown }
        if (typeof id !== "string" || !TOGGLE_IDS.includes(id as ClothingToggleId)) continue
        list.push({ id: id as ClothingToggleId, removed: removed === true })
    }
    return list
}

/** Flipping a switch asks for the opposite of what the game last reported. */
export function toggleRequest(toggle: ClothingToggle): SetClothingTogglePayload {
    return { id: toggle.id, removed: !toggle.removed }
}

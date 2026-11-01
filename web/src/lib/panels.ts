import type { HeadPayload, HeadValues } from "./types"

// Shared/components.lua component ids. The Style group lists Face, Mask and
// Hair as items; each side panel belongs to exactly one of them.
export const FACE_COMPONENT_ID = 0
export const HAIR_COMPONENT_ID = 2

type Selected = { kind: string; id: number } | undefined

export type OverlayKey = "facialHair" | "eyebrows" | "chestHair"

export const HEAD_OVERLAYS: {
    key: OverlayKey
    label: string
    style: "beard" | "eyebrows" | "chestHair"
    opacity: "beardOpacity" | "eyebrowsOpacity" | "chestHairOpacity"
    color: "beardColor" | "eyebrowsColor" | "chestHairColor"
    maxStyle: number
}[] = [
    { key: "facialHair", label: "Facial Hair", style: "beard", opacity: "beardOpacity", color: "beardColor", maxStyle: 28 },
    { key: "eyebrows", label: "Eyebrows", style: "eyebrows", opacity: "eyebrowsOpacity", color: "eyebrowsColor", maxStyle: 33 },
    { key: "chestHair", label: "Chest Hair", style: "chestHair", opacity: "chestHairOpacity", color: "chestHairColor", maxStyle: 15 },
]

export type HairSection = "hair" | OverlayKey

/** Sections of the Hair item: Hair itself plus every overlay the server allows.
 * Empty when there is nothing to choose between (no overlays), so the menu
 * keeps its single-section layout. */
export function hairSections(overlays: { key: OverlayKey; label: string }[]): { key: HairSection; label: string }[] {
    if (overlays.length === 0) return []
    return [{ key: "hair", label: "Hair" }, ...overlays.map(({ key, label }) => ({ key, label }))]
}

/** The chosen section, falling back to Hair when it is not offered (a toggled-off overlay). */
export function activeHairSection(sections: { key: HairSection }[], chosen: HairSection): HairSection {
    return sections.some((section) => section.key === chosen) ? chosen : "hair"
}

function isComponent(selected: Selected, id: number) {
    return selected?.kind === "component" && selected.id === id
}

/** Skin tone panel: only on the Face item, and only where skin tone is editable. */
export function showFaceSkinPanel(selected: Selected, head: HeadPayload | null) {
    return !!head && head.skinToneEditable === true && isComponent(selected, FACE_COMPONENT_ID)
}

/** Overlays the server allowed for this service; the panel shows on the Hair item. */
export function enabledOverlays(selected: Selected, head: HeadPayload | null) {
    if (!head || !isComponent(selected, HAIR_COMPONENT_ID)) return []
    return HEAD_OVERLAYS.filter((overlay) => head.overlays?.[overlay.key] === true)
}

/** Whether the overlay has its own colour palette; false when the server locks it to the hair colour. */
export function overlayColorEditable(head: HeadPayload, key: OverlayKey) {
    return head.overlayColors?.[key] !== false
}

/** First tab/item of a session. Character creation (skin tone editable) opens
 * on Style with Hair selected, so hair, hair colour, facial hair and eyebrows
 * are visible straight away; Config.ui.creatorOpensOnHair = false opts out. */
export function initialSelection<T extends { kind: string; id: number; category: string }>(
    categories: T[], groupOrder: string[], creator: boolean, opensOnHair: boolean | undefined,
): { group: string | undefined; item: T | undefined } {
    if (creator && opensOnHair !== false) {
        const hair = categories.find((item) => item.kind === "component" && item.id === HAIR_COMPONENT_ID)
        if (hair) return { group: hair.category, item: hair }
    }
    const group = groupOrder.find((candidate) => categories.some((item) => item.category === candidate))
    return { group, item: categories.find((item) => item.category === group) }
}

/** Keeps the editor flags while taking the values the game confirmed. */
export function mergeHeadValues(current: HeadPayload, values: HeadValues): HeadPayload {
    return { ...current, ...values }
}

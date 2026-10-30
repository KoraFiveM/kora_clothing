import type { HeadPayload, HeadValues } from "./types"

// Shared/components.lua component ids. The Style group lists Face, Mask and
// Hair as items; each side panel belongs to exactly one of them.
export const FACE_COMPONENT_ID = 0
export const HAIR_COMPONENT_ID = 2

type Selected = { kind: string; id: number } | undefined

export type OverlayKey = "facialHair" | "eyebrows"

export const HEAD_OVERLAYS: {
    key: OverlayKey
    label: string
    style: "beard" | "eyebrows"
    opacity: "beardOpacity" | "eyebrowsOpacity"
    color: "beardColor" | "eyebrowsColor"
    maxStyle: number
}[] = [
    { key: "facialHair", label: "Facial hair", style: "beard", opacity: "beardOpacity", color: "beardColor", maxStyle: 28 },
    { key: "eyebrows", label: "Eyebrows", style: "eyebrows", opacity: "eyebrowsOpacity", color: "eyebrowsColor", maxStyle: 33 },
]

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

/** Keeps the editor flags while taking the values the game confirmed. */
export function mergeHeadValues(current: HeadPayload, values: HeadValues): HeadPayload {
    return { ...current, ...values }
}

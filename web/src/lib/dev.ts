import type { NuiWireMessage, OpenPayload } from "./types"

const sample: OpenPayload = {
    mode: "shop",
    service: "clothing",
    free: false,
    mandatory: false,
    shopLabel: "Suburban",
    model: "mp_m_freemode_01",
    categories: [
        { kind: "component", id: 0, label: "Face", category: "body", drawable: 0, texture: 0, drawableCount: 1, textureCount: 1 },
        { kind: "component", id: 2, label: "Hair", category: "body", drawable: 5, texture: 0, drawableCount: 38, textureCount: 3 },
        { kind: "component", id: 3, label: "Torso", category: "tops", drawable: 14, texture: 2, drawableCount: 62, textureCount: 8 },
        { kind: "component", id: 8, label: "Undershirt", category: "tops", drawable: 15, texture: 0, drawableCount: 34, textureCount: 5 },
        { kind: "component", id: 9, label: "Kevlar", category: "tops", drawable: 0, texture: 0, drawableCount: 2, textureCount: 1 },
        { kind: "component", id: 11, label: "Torso 2", category: "tops", drawable: 0, texture: 0, drawableCount: 20, textureCount: 4 },
        { kind: "component", id: 4, label: "Legs", category: "legs", drawable: 21, texture: 1, drawableCount: 96, textureCount: 6 },
        { kind: "component", id: 6, label: "Shoes", category: "shoes", drawable: 12, texture: 0, drawableCount: 78, textureCount: 4 },
        { kind: "component", id: 5, label: "Bag", category: "accessories", drawable: 0, texture: 0, drawableCount: 16, textureCount: 2 },
        { kind: "component", id: 7, label: "Accessory", category: "accessories", drawable: 0, texture: 0, drawableCount: 22, textureCount: 3 },
        { kind: "component", id: 10, label: "Badge", category: "accessories", drawable: 0, texture: 0, drawableCount: 10, textureCount: 1 },
        { kind: "prop", id: 0, label: "Hat", category: "accessories", clearable: true, drawable: -1, texture: 0, drawableCount: 34, textureCount: 0 },
        { kind: "prop", id: 1, label: "Glasses", category: "accessories", clearable: true, drawable: -1, texture: 0, drawableCount: 20, textureCount: 0 },
        { kind: "prop", id: 2, label: "Ears", category: "accessories", clearable: true, drawable: -1, texture: 0, drawableCount: 12, textureCount: 0 },
        { kind: "prop", id: 6, label: "Watch", category: "accessories", clearable: true, drawable: -1, texture: 0, drawableCount: 8, textureCount: 0 },
        { kind: "prop", id: 7, label: "Bracelet", category: "accessories", clearable: true, drawable: -1, texture: 0, drawableCount: 6, textureCount: 0 },
    ],
    tattoos: [
        { id: "airraces_turbulence", label: "Turbulence", group: "Torso", price: 125 },
        { id: "hipster_anchor", label: "Anchor", group: "Arms", price: 130 },
    ],
    selectedTattoos: [],
    outfits: [
        { id: 1, outfitname: "Interview fit", model: "mp_m_freemode_01" },
        { id: 2, outfitname: "Night out", model: "mp_m_freemode_01" },
    ],
    money: { cash: 4250, bank: 18900 },
    prices: { tops: 175, legs: 150, shoes: 120, body: 90, accessories: 60 },
    currency: "cash",
}

export function openDevHarness() {
    const post = <T,>(action: string, data: T) => window.postMessage({ action, data } satisfies NuiWireMessage<T>, "*")
    post("qbclothing:nui:theme", { primary: "348 83% 47%", ring: "348 83% 47%", "brand-soft": "348 83% 47% / .14", "brand-border": "348 83% 47% / .45" })
    post("qbclothing:nui:open", sample)
}

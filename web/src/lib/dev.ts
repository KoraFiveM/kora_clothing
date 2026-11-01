import type { HairSwatch, NuiWireMessage, OpenPayload } from "./types"

// Stand-in for what GetPedHairRgbColor reports index by index in-game. Only
// the browser harness ever sees these -- a real session gets the game's own
// palette, which is why the grid paints from the payload rather than from a
// hardcoded list of colours.
const hairPalette: HairSwatch[] = [
    [26, 22, 20], [58, 41, 30], [86, 60, 39], [120, 86, 54], [156, 118, 74], [193, 160, 110],
    [214, 190, 148], [232, 220, 190], [151, 61, 34], [178, 92, 46], [120, 44, 44], [92, 46, 62],
    [64, 64, 72], [110, 112, 120], [160, 162, 170], [206, 208, 214], [78, 52, 96], [40, 66, 110],
    [36, 100, 96], [110, 130, 58], [186, 150, 40], [190, 96, 130], [58, 30, 46], [30, 30, 34],
].map(([r, g, b], index) => ({ index, r, g, b }))

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
        { kind: "component", id: 3, label: "Arms", category: "tops", drawable: 14, texture: 2, drawableCount: 62, textureCount: 8 },
        { kind: "component", id: 8, label: "Undershirt", category: "tops", drawable: 15, texture: 0, drawableCount: 34, textureCount: 5 },
        { kind: "component", id: 9, label: "Kevlar", category: "tops", drawable: 0, texture: 0, drawableCount: 2, textureCount: 1 },
        { kind: "component", id: 11, label: "Jackets", category: "tops", drawable: 0, texture: 0, drawableCount: 20, textureCount: 4 },
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
    hair: { palette: hairPalette, color: 2, highlight: 8 },
    head: {
        skinTone: 0, beard: -1, beardOpacity: 1, beardColor: -1, eyebrows: -1, eyebrowsOpacity: 1, eyebrowsColor: -1,
        chestHair: -1, chestHairOpacity: 1, chestHairColor: -1,
        skinToneEditable: false, overlays: { facialHair: true, eyebrows: true, chestHair: true },
    },
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
    post("qbclothing:nui:open", sample)
}

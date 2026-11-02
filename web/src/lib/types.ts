import type { ClothingToggle } from "./clothingToggles.ts"
import type { UndressPayload } from "./undress.ts"

export interface NuiWireMessage<T = unknown> {
    action: string
    data: T
}

export type ThemeTokens = Record<string, string>

export type ClothingMode = "firstCharacter" | "shop" | "wardrobe"

export type CategoryGroup = "tops" | "legs" | "shoes" | "body" | "accessories"

export interface ClothingCategoryItem {
    kind: "component" | "prop"
    id: number
    label: string
    category: CategoryGroup
    clearable?: boolean
    drawable: number
    texture: number
    drawableCount: number
    textureCount: number
}

export interface OutfitSummary {
    id: number
    outfitname: string
    model: string
}

export interface MoneyInfo {
    cash?: number
    bank?: number
    crypto?: number
}

export type PriceTable = Partial<Record<CategoryGroup, number>>

/** Config.tattoo stacking options, sent by the game when the studio opens. */
export interface TattooStacking {
    enabled: boolean
    max: number
    priceMultiplier: number
}

export interface TattooItem {
    id: string
    label: string
    group: string
    price: number
}

/** One entry of GTA's fixed hair palette: the index SetPedHairColor actually
 * accepts, plus the RGB the game reports for it (GetPedHairRgbColor) purely so
 * the swatch can be painted. The index is what travels back over the wire --
 * there is no RGB form the native would take. */
export interface HairSwatch {
    index: number
    r: number
    g: number
    b: number
}

/** Absent (null) for services that cannot edit the hair component at all --
 * an ordinary clothing shop gets no palette, so the UI shows no grids. */
export interface HairPayload {
    palette: HairSwatch[]
    color: number
    highlight: number
}

/** Saved head values. Opacity is 0..1; a colour of -1 follows the hair colour. */
export interface HeadValues {
    skinTone: number
    beard: number
    beardOpacity: number
    beardColor: number
    eyebrows: number
    eyebrowsOpacity: number
    eyebrowsColor: number
    chestHair: number
    chestHairOpacity: number
    chestHairColor: number
}

export interface HeadPayload extends HeadValues {
    /** Skin tone is creation-only. */
    skinToneEditable?: boolean
    /** Which overlays this service may edit (Config.headOverlays). */
    overlays?: { facialHair: boolean; eyebrows: boolean; chestHair?: boolean }
    /** Whether each overlay has a colour palette of its own (false: locked to the hair colour). */
    overlayColors?: { facialHair: boolean; eyebrows: boolean; chestHair?: boolean }
}

export interface OpenPayload {
    mode: ClothingMode
    service: string
    free: boolean
    mandatory: boolean
    rotatePointerLock?: boolean
    rotateDragGuard?: boolean
    /** Config.rotateMode; absent (an older Lua side) means the pointer-lock drag. */
    rotateMode?: "capture" | "controls" | "recenter" | "pointer" | "plain"
    /** Config.rotateRightButton; absent means on. */
    rotateRightButton?: boolean
    /** Config.rotateInvert; absent means not inverted. */
    rotateInvert?: boolean
    /** Config.rotateSensitivity (pointer, recenter, plain); absent means 1. */
    rotateSensitivity?: number
    /** Config.rotateRecenterEdge (recenter mode); absent means the built-in default. */
    rotateRecenterEdge?: number
    /** Config.ui.showControlsHint; absent means on. */
    showControlsHint?: boolean
    /** Config.ui.showScrollbar; absent means hidden. */
    showScrollbar?: boolean
    /** Config.ui.creatorOpensOnHair; absent means on. */
    creatorOpensOnHair?: boolean
    shopLabel?: string
    model: string
    categories: ClothingCategoryItem[]
    hair?: HairPayload | null
    head?: HeadPayload | null
    /** Tattoo studio clothing buttons (Config.tattoo.undress); absent elsewhere. */
    undress?: UndressPayload | null
    /** Preview clothing switches (Config.ui.clothingToggles); absent where the menu has none. */
    clothingToggles?: ClothingToggle[] | null
    /** Menu text from the game's locale files; see strings.ts. */
    strings?: Record<string, string>
    tattoos: TattooItem[]
    selectedTattoos: string[]
    tattooStacking?: TattooStacking
    outfits: OutfitSummary[]
    money?: MoneyInfo
    prices: PriceTable
    currency: string
}

export interface ErrorPayload {
    message: string
}

export interface SetVariationPayload {
    kind: "component" | "prop"
    id: number
    drawable: number
    texture: number
}

export interface SetVariationResponse {
    ok: boolean
    drawable?: number
    texture?: number
    drawableCount?: number
    textureCount?: number
}

export interface CameraPayload {
    zone: "full" | "face" | "torso" | "legs" | "shoes"
}

/** A clothing group or tattoo group; the game maps it to a zone. */
export interface CategoryCameraPayload {
    category: string
}
export interface CategoryCameraResponse {
    zone?: CameraPayload["zone"]
}

/** Wheel notches, not pixels -- see the comment on useZoom in App.tsx. */
export interface ZoomPayload {
    delta: number
}

export interface SetHairColorPayload {
    color: number
    highlight: number
}

export interface SetHairColorResponse {
    ok: boolean
    color?: number
    highlight?: number
}

export type SetHeadPayload = HeadValues
export interface SetHeadResponse { ok: boolean; head?: HeadValues }

export interface RotatePayload {
    deltaDeg: number
}

export interface LoadOutfitResponse {
    ok: boolean
    model?: string
    categories?: ClothingCategoryItem[]
    hair?: HairPayload | null
    head?: HeadPayload | null
    selectedTattoos?: string[]
    undress?: UndressPayload | null
    clothingToggles?: ClothingToggle[] | null
}

export interface ConfirmPayload {
    saveName?: string
}

export interface ConfirmResponse {
    ok: boolean
}

export interface SetTattoosResponse {
    ok: boolean
    tattoos?: string[]
}

export interface CancelResponse {
    ok: boolean
}

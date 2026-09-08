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

export interface HeadPayload {
    skinTone: number
    beard: number
}

export interface OpenPayload {
    mode: ClothingMode
    service: string
    free: boolean
    mandatory: boolean
    shopLabel?: string
    model: string
    categories: ClothingCategoryItem[]
    hair?: HairPayload | null
    head?: HeadPayload | null
    tattoos: TattooItem[]
    selectedTattoos: string[]
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

export interface SetHeadPayload { skinTone: number; beard: number }
export interface SetHeadResponse extends Partial<HeadPayload> { ok: boolean }

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

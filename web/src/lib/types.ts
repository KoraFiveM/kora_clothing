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

export type PriceTable = Record<CategoryGroup, number>

export interface OpenPayload {
    mode: ClothingMode
    mandatory: boolean
    shopLabel?: string
    model: string
    categories: ClothingCategoryItem[]
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

export interface RotatePayload {
    deltaDeg: number
}

export interface LoadOutfitResponse {
    ok: boolean
    model?: string
    categories?: ClothingCategoryItem[]
}

export interface ConfirmPayload {
    saveName?: string
}

export interface ConfirmResponse {
    ok: boolean
}

export interface CancelResponse {
    ok: boolean
}

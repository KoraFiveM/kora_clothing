// Menu text for the hair, grooming and clothing switch controls. The game sends the
// resolved text with the session (locales/en.json plus any translation kora_lib
// finds for the server's language), so wording is changed in the locale files,
// not here. These defaults only cover the browser dev harness and a payload
// without strings; strings.test.ts keeps them identical to locales/en.json.

export const DEFAULT_STRINGS = {
    hair: "Hair",
    facialHair: "Facial Hair",
    eyebrows: "Eyebrows",
    chestHair: "Chest Hair",
    style: "Style",
    variant: "Variant",
    opacity: "Opacity",
    color: "Color",
    primaryColor: "Primary Color (Base)",
    secondaryColor: "Secondary Color (Highlights)",
    none: "None",
    clothingToggles: "Clothing",
    hat: "Hat",
    shirt: "Shirt",
    pants: "Pants",
    shoes: "Shoes",
    toggleOn: "On",
    toggleOff: "Off",
    togglesHint: "Preview only: nothing is saved or charged",
}

export type StringKey = keyof typeof DEFAULT_STRINGS
export type Strings = Record<StringKey, string>

/** The defaults with any known key the game sent as non-empty text laid over them. */
export function resolveStrings(received: unknown): Strings {
    const strings: Strings = { ...DEFAULT_STRINGS }
    if (!received || typeof received !== "object") return strings
    for (const key of Object.keys(DEFAULT_STRINGS) as StringKey[]) {
        const value = (received as Record<string, unknown>)[key]
        if (typeof value === "string" && value.trim() !== "") strings[key] = value
    }
    return strings
}

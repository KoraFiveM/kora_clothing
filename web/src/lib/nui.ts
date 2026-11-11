declare global {
    interface Window {
        GetParentResourceName?: () => string
        invokeNative?: (...args: unknown[]) => unknown
    }
}

const browser = typeof window.invokeNative !== "function"

function resourceName() {
    return window.GetParentResourceName?.() ?? "kora_clothing"
}

/** The sole browser-to-Lua transport. Every RegisterNUICallback name the Lua
 * side registers gets posted to here, with the JSON-decoded response handed
 * back to the caller. */
export async function sendIntent<TPayload extends object, TResponse>(name: string, payload: TPayload): Promise<TResponse> {
    if (browser) return {} as TResponse

    const response = await fetch(`https://${resourceName()}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(payload),
    })
    return response.json() as Promise<TResponse>
}

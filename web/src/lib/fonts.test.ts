// The UI follows kora_theme's configurable fonts: body text inherits --font-sans
// from theme.css, titles use --font-heading, and every font-family keeps the
// stock stack as its fallback so it looks the same when the vars are unset.
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"

const css = readFileSync(new URL("../styles.css", import.meta.url), "utf8")
const rule = (selector: string) => css.split("\n").filter((line) => line.startsWith(`${selector} {`)).join("\n")
const sans = 'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'

test("titles use the theme heading font, falling back to the body font", () => {
    for (const selector of [".headline h1", ".detail-title"]) {
        assert.ok(rule(selector).includes(`font-family: var(--font-heading, var(--font-sans, ${sans}));`), selector)
    }
})

test("every font-family follows a theme font variable with a fallback", () => {
    for (const match of css.matchAll(/font-family:\s*([^;]+);/g)) {
        assert.match(match[1], /^var\(--font-(sans|heading|mono), .+\)$/, match[0])
    }
})

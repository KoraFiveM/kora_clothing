import { ChevronDown, ChevronLeft, ChevronRight, CircleAlert, Footprints, Gem, Maximize2, PersonStanding, Save, Shirt, Smile, Trash2, User, X } from "lucide-react"
import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import { openDevHarness } from "@/lib/dev"
import { sendIntent } from "@/lib/nui"
import type {
    CameraPayload,
    CancelResponse,
    CategoryGroup,
    ClothingCategoryItem,
    ClothingMode,
    ConfirmPayload,
    ConfirmResponse,
    ErrorPayload,
    HairPayload,
    HeadPayload,
    HeadValues,
    HairSwatch,
    LoadOutfitResponse,
    OpenPayload,
    OutfitSummary,
    PriceTable,
    RotatePayload,
    SetHairColorPayload,
    SetHairColorResponse,
    SetHeadPayload,
    SetHeadResponse,
    SetVariationPayload,
    SetVariationResponse,
    SetTattoosResponse,
    TattooItem,
    ZoomPayload,
} from "@/lib/types"
import { enabledOverlays, HAIR_COMPONENT_ID, HEAD_OVERLAYS, mergeHeadValues, showFaceSkinPanel } from "@/lib/panels"
import { useNuiEvent } from "@/lib/useNuiEvent"

const GROUP_ORDER: CategoryGroup[] = ["tops", "legs", "shoes", "body", "accessories"]
const GROUP_LABEL: Record<CategoryGroup, string> = { tops: "Tops", legs: "Legs", shoes: "Shoes", body: "Style", accessories: "Accessories" }
const GROUP_ICON: Record<CategoryGroup, typeof Shirt> = { tops: Shirt, legs: PersonStanding, shoes: Footprints, body: Smile, accessories: Gem }

type Zone = CameraPayload["zone"]
const ZONES: { zone: Zone; label: string; icon: typeof Maximize2 }[] = [
    { zone: "full", label: "Full body", icon: Maximize2 },
    { zone: "face", label: "Face", icon: Smile },
    { zone: "torso", label: "Torso", icon: Shirt },
    { zone: "legs", label: "Legs", icon: PersonStanding },
    { zone: "shoes", label: "Shoes", icon: Footprints },
]

// Config.camera.zones (client/camera.lua) has no per-limb preset, so a tattoo
// group without a dedicated zoom (Arms, Back) falls back to the closest
// available framing rather than staying wherever the toolbar was last left.
const TATTOO_ZONE: Record<string, Zone> = { Head: "face", Torso: "torso", Back: "torso", Arms: "torso", Legs: "legs" }

function itemKey(item: Pick<ClothingCategoryItem, "kind" | "id">) {
    return `${item.kind}:${item.id}`
}

function headlineCopy(mode: ClothingMode, shopLabel?: string, service?: string) {
    if (mode === "firstCharacter") return { badge: undefined, title: "Make yourself at home", sub: "Choose how you want to look before you step outside." }
    if (mode === "shop") {
        const title = service === "tattoo" ? "Tattoo Studio" : service === "barber" ? "Barber" : service === "hairdresser" ? "Hairdresser" : "Fitting Room"
        return { badge: shopLabel, title, sub: "Try changes before you confirm them." }
    }
    return { badge: undefined, title: "Your Wardrobe", sub: "Preview a look or save the one you're wearing." }
}

function confirmLabel(mode: ClothingMode, total: number) {
    if (mode === "firstCharacter") return "Confirm"
    if (mode === "shop") return total > 0 ? `Buy & Wear · $${total.toLocaleString()}` : "Wear · Free"
    if (mode === "wardrobe" && total > 0) return `Save & Wear · $${total.toLocaleString()}`
    return "Save & Wear"
}

const DRAG_ROTATION_DEG_PER_PIXEL = 0.15

/** Drag-to-rotate needs to feel continuous but must not spam the NUI
 * callback on every pointermove -- coalesce into at most one call per frame. */
function useRotate() {
    const pending = useRef(0)
    const frame = useRef<number | null>(null)
    const flush = useCallback(() => {
        frame.current = null
        if (pending.current === 0) return
        const deltaDeg = pending.current
        pending.current = 0
        void sendIntent<RotatePayload, object>("qbclothing:nui:rotate", { deltaDeg })
    }, [])
    return useCallback((delta: number) => {
        pending.current += delta
        if (frame.current === null) frame.current = requestAnimationFrame(flush)
    }, [flush])
}

/** Free zoom on the wheel, coalesced per frame like the drag above. Only the
 * SIGN of deltaY is used: its magnitude is meaningless across inputs (a mouse
 * notch reports ~100px in CEF, a trackpad reports single-digit pixels per
 * event, and deltaMode can report lines or pages instead), so forwarding it
 * raw would make one notch of the same gesture worth ten of another. Lua turns
 * a notch into metres via Config.camera.zoom.step. */
function useZoom() {
    const pending = useRef(0)
    const frame = useRef<number | null>(null)
    const flush = useCallback(() => {
        frame.current = null
        if (pending.current === 0) return
        const delta = pending.current
        pending.current = 0
        void sendIntent<ZoomPayload, object>("qbclothing:nui:zoom", { delta })
    }, [])
    return useCallback((notches: number) => {
        pending.current += notches
        if (frame.current === null) frame.current = requestAnimationFrame(flush)
    }, [flush])
}

function Viewport({ onRotate, onZoom }: { onRotate: (deltaDeg: number) => void; onZoom: (notches: number) => void }) {
    const dragging = useRef(false)
    return <div
        className="clothing-viewport"
        onPointerDown={(event) => { dragging.current = true; event.currentTarget.setPointerCapture(event.pointerId) }}
        onPointerUp={(event) => { dragging.current = false; event.currentTarget.releasePointerCapture(event.pointerId) }}
        onPointerCancel={() => { dragging.current = false }}
        onPointerMove={(event) => { if (dragging.current) onRotate(-event.movementX * DRAG_ROTATION_DEG_PER_PIXEL) }}
        onWheel={(event) => onZoom(Math.sign(event.deltaY))}
        aria-hidden="true"
    />
}

function ZoneToolbar({ zone, onSelect }: { zone: Zone; onSelect: (zone: Zone) => void }) {
    return <div className="zone-toolbar">
        {ZONES.map(({ zone: z, label, icon: Icon }) => (
            <button key={z} type="button" aria-label={label} aria-pressed={zone === z} onClick={() => onSelect(z)}>
                <Icon size={16} />
            </button>
        ))}
    </div>
}

function CategoryTabs({ active, groups, onSelect }: { active: CategoryGroup; groups: Set<CategoryGroup>; onSelect: (group: CategoryGroup) => void }) {
    return <nav className="tab-list" aria-label="Clothing categories">
        {GROUP_ORDER.filter((group) => groups.has(group)).map((group) => {
            const Icon = GROUP_ICON[group]
            return <button key={group} type="button" className="tab" aria-pressed={active === group} onClick={() => onSelect(group)}>
                <Icon size={16} /><span>{GROUP_LABEL[group]}</span>
            </button>
        })}
    </nav>
}

function ItemList({ items, selectedKey, onSelect }: { items: ClothingCategoryItem[]; selectedKey?: string; onSelect: (item: ClothingCategoryItem) => void }) {
    return <div className="item-list">
        {items.map((item) => {
            const key = itemKey(item)
            const removed = item.kind === "prop" && item.drawable < 0
            return <button key={key} type="button" className="item-row" aria-pressed={selectedKey === key} onClick={() => onSelect(item)}>
                <span>{item.label}</span>
                {removed && <span className="removed-badge">None</span>}
            </button>
        })}
    </div>
}

function VariationDetail({ item, onChange, onClear }: {
    item?: ClothingCategoryItem
    onChange: (next: { drawable: number; texture: number }) => void
    onClear: () => void
}) {
    if (!item) return <div className="empty-panel"><User size={26} /><span>Pick an item from the list to adjust it.</span></div>

    const removed = item.kind === "prop" && item.drawable < 0
    const canPrevDrawable = item.kind === "prop" && item.clearable ? item.drawable > -1 : item.drawable > 0
    const canNextDrawable = item.drawable < item.drawableCount - 1
    const canPrevTexture = !removed && item.texture > 0
    const canNextTexture = !removed && item.texture < item.textureCount - 1

    return <div>
        <h3 className="detail-title">{item.label}</h3>
        <p className="detail-sub">{item.kind === "component" ? "Clothing item" : "Accessory"}</p>

        <div className="stepper">
            <label>Style</label>
            <button type="button" className="step-btn" aria-label="Previous style" disabled={!canPrevDrawable} onClick={() => onChange({ drawable: item.drawable - 1, texture: 0 })}><ChevronLeft size={16} /></button>
            <span>{removed ? "None" : `${item.drawable + 1} / ${item.drawableCount}`}</span>
            <button type="button" className="step-btn" aria-label="Next style" disabled={!canNextDrawable} onClick={() => onChange({ drawable: item.drawable + 1, texture: 0 })}><ChevronRight size={16} /></button>
        </div>

        <div className="stepper">
            <label>Color</label>
            <button type="button" className="step-btn" aria-label="Previous color" disabled={!canPrevTexture} onClick={() => onChange({ drawable: item.drawable, texture: item.texture - 1 })}><ChevronLeft size={16} /></button>
            <span>{removed ? "--" : `${item.texture + 1} / ${Math.max(item.textureCount, 1)}`}</span>
            <button type="button" className="step-btn" aria-label="Next color" disabled={!canNextTexture} onClick={() => onChange({ drawable: item.drawable, texture: item.texture + 1 })}><ChevronRight size={16} /></button>
        </div>

        {item.kind === "prop" && item.clearable && !removed && (
            <button type="button" className="remove-action" onClick={onClear}>Remove</button>
        )}
    </div>
}

/** A swatch grid, not a colour picker, and deliberately so: GTA's
 * SetPedHairColor takes a palette INDEX and there is no native that accepts an
 * RGB triple, so a free picker would have nothing to send. Each swatch is
 * painted with the RGB the game reports for its own index
 * (GetPedHairRgbColor, read client-side and sent with the session payload) --
 * that gives the look of a picker while every value posted back stays a legal
 * index. The colours come from the game at runtime, which is why these are
 * inline styles rather than classes. */
function HairColorGrid({ label, palette, value, onSelect }: {
    label: string
    palette: HairSwatch[]
    value: number
    onSelect: (index: number) => void
}) {
    return <div className="swatch-block">
        <p className="swatch-label">{label}</p>
        <div className="swatch-grid" role="radiogroup" aria-label={label}>
            {palette.map((swatch) => (
                <button
                    key={swatch.index}
                    type="button"
                    role="radio"
                    className="swatch"
                    aria-checked={value === swatch.index}
                    aria-label={`${label} ${swatch.index + 1}`}
                    style={{ background: `rgb(${swatch.r} ${swatch.g} ${swatch.b})` }}
                    onClick={() => onSelect(swatch.index)}
                />
            ))}
        </div>
    </div>
}

function HairColorPanel({ hair, onChange }: {
    hair: HairPayload
    onChange: (next: { color: number; highlight: number }) => void
}) {
    if (hair.palette.length === 0) return null
    return <div className="panel panel-pad hair-panel">
        <p className="section-title">Hair Color</p>
        <HairColorGrid label="Primary (Base)" palette={hair.palette} value={hair.color} onSelect={(index) => onChange({ color: index, highlight: hair.highlight })} />
        <HairColorGrid label="Secondary (Highlights)" palette={hair.palette} value={hair.highlight} onSelect={(index) => onChange({ color: hair.color, highlight: index })} />
    </div>
}

function Stepper({ label, text, canPrev, canNext, onPrev, onNext }: {
    label: string
    text: string
    canPrev: boolean
    canNext: boolean
    onPrev: () => void
    onNext: () => void
}) {
    return <div className="stepper">
        <label>{label}</label>
        <button type="button" className="step-btn" aria-label={`Previous ${label}`} disabled={!canPrev} onClick={onPrev}><ChevronLeft size={16} /></button>
        <span>{text}</span>
        <button type="button" className="step-btn" aria-label={`Next ${label}`} disabled={!canNext} onClick={onNext}><ChevronRight size={16} /></button>
    </div>
}

/** Skin tone, shown with the Face item only. */
function FaceSkinPanel({ head, onChange }: { head: HeadPayload; onChange: (next: HeadValues) => void }) {
    return <div className="panel panel-pad head-panel">
        <p className="section-title">Face & Skin</p>
        <Stepper
            label="Skin tone" text={`${head.skinTone + 1} / 46`}
            canPrev={head.skinTone > 0} canNext={head.skinTone < 45}
            onPrev={() => onChange({ ...head, skinTone: head.skinTone - 1 })} onNext={() => onChange({ ...head, skinTone: head.skinTone + 1 })}
        />
    </div>
}

const OPACITY_STEP = 0.1

/** Style, opacity and colour for each overlay the server allows here, shown
 * with the Hair item beside the hair colour. Colour reuses the hair palette;
 * with none selected the overlay follows the hair colour. */
function HeadOverlayPanel({ head, overlays, palette, onChange }: {
    head: HeadPayload
    overlays: ReturnType<typeof enabledOverlays>
    palette: HairSwatch[]
    onChange: (next: HeadValues) => void
}) {
    return <>
        {overlays.map((overlay) => {
            const style = head[overlay.style]
            const opacity = head[overlay.opacity]
            return <div key={overlay.key} className="panel panel-pad head-panel">
                <p className="section-title">{overlay.label}</p>
                <Stepper
                    label={`${overlay.label} style`} text={style < 0 ? "None" : `${style + 1} / ${overlay.maxStyle + 1}`}
                    canPrev={style > -1} canNext={style < overlay.maxStyle}
                    onPrev={() => onChange({ ...head, [overlay.style]: style - 1 })} onNext={() => onChange({ ...head, [overlay.style]: style + 1 })}
                />
                <Stepper
                    label={`${overlay.label} opacity`} text={`${Math.round(opacity * 100)}%`}
                    canPrev={opacity > 0} canNext={opacity < 1}
                    onPrev={() => onChange({ ...head, [overlay.opacity]: Math.max(0, Math.round((opacity - OPACITY_STEP) * 100) / 100) })}
                    onNext={() => onChange({ ...head, [overlay.opacity]: Math.min(1, Math.round((opacity + OPACITY_STEP) * 100) / 100) })}
                />
                {style >= 0 && palette.length > 0 && <HairColorGrid
                    label={`${overlay.label} colour`} palette={palette} value={head[overlay.color]}
                    onSelect={(index) => onChange({ ...head, [overlay.color]: index })}
                />}
            </div>
        })}
    </>
}

function OutfitsPanel({ outfits, expanded, onToggle, onWear, onDelete }: {
    outfits: OutfitSummary[]
    expanded: boolean
    onToggle: () => void
    onWear: (id: number) => void
    onDelete: (id: number) => void
}) {
    return <div className="panel">
        <button type="button" className="outfits-toggle" aria-expanded={expanded} onClick={onToggle}>
            <span>My Outfits ({outfits.length})</span>
            <ChevronDown size={16} />
        </button>
        {expanded && <div className="outfits-body">
            {outfits.length === 0 && <p className="outfits-empty">No saved outfits yet. Save the look you're wearing below.</p>}
            {outfits.map((outfit) => (
                <div key={outfit.id} className="outfit-card">
                    <div className="outfit-info">
                        <span className="outfit-name">{outfit.outfitname}</span>
                        <span className="outfit-model">{outfit.model}</span>
                    </div>
                    <div className="outfit-actions">
                        <button type="button" className="icon-btn" aria-label={`Wear ${outfit.outfitname}`} onClick={() => onWear(outfit.id)}><User size={14} /></button>
                        <button type="button" className="icon-btn danger" aria-label={`Delete ${outfit.outfitname}`} onClick={() => onDelete(outfit.id)}><Trash2 size={14} /></button>
                    </div>
                </div>
            ))}
        </div>}
    </div>
}

function TattooPanel({ tattoos, selected, onToggle }: { tattoos: TattooItem[]; selected: string[]; onToggle: (id: string) => void }) {
    if (tattoos.length === 0) return null
    const selectedSet = new Set(selected)
    return <div className="panel panel-pad tattoo-panel">
        <p className="section-title">Tattoos</p>
        <div className="tattoo-list">
            {tattoos.map((tattoo) => <label key={tattoo.id} className="tattoo-row">
                <input type="checkbox" checked={selectedSet.has(tattoo.id)} onChange={() => onToggle(tattoo.id)} />
                <span className="tattoo-copy"><strong>{tattoo.label}</strong><small>{tattoo.group}</small></span>
                <span className="tattoo-price">${tattoo.price}</span>
            </label>)}
        </div>
    </div>
}

function priceOf(prices: PriceTable | undefined, group: CategoryGroup) {
    return prices?.[group] ?? 0
}

export default function App() {
    const [open, setOpen] = useState<OpenPayload | null>(null)
    const [categories, setCategories] = useState<ClothingCategoryItem[]>([])
    const [selectedTattoos, setSelectedTattoos] = useState<string[]>([])
    const [hair, setHair] = useState<HairPayload | null>(null)
    const [head, setHead] = useState<HeadPayload | null>(null)
    // Held separately from `hair` for the same reason `baseline` is held apart
    // from `categories`: the price shown has to be a diff against what the
    // player walked in with, and `hair` moves with every swatch click.
    const [baselineHair, setBaselineHair] = useState<{ color: number; highlight: number } | null>(null)
    const [baselineHead, setBaselineHead] = useState<HeadPayload | null>(null)
    const [baselineTattoos, setBaselineTattoos] = useState<string[]>([])
    const [baseline, setBaseline] = useState<Map<string, { drawable: number; texture: number }>>(new Map())
    // Set right after loading a saved outfit via "Wear", cleared on any
    // manual edit -- while it's set, the player is looking at exactly what
    // they already own, which the server prices as free (see
    // ownedOutfitMatch in server/server.lua). Kept as a flag rather than
    // re-deriving equality client-side since the browser never receives full
    // skin data for every saved outfit, only the one just loaded.
    const [ownedSnapshot, setOwnedSnapshot] = useState(false)
    const [outfits, setOutfits] = useState<OutfitSummary[]>([])
    const [activeGroup, setActiveGroup] = useState<CategoryGroup>("tops")
    const [selectedKey, setSelectedKey] = useState<string>()
    const [zone, setZone] = useState<Zone>("full")
    const [error, setError] = useState<string>()
    const [saveName, setSaveName] = useState("")
    const [outfitsExpanded, setOutfitsExpanded] = useState(false)
    const [confirmPending, setConfirmPending] = useState(false)

    const rotate = useRotate()
    const zoom = useZoom()

    const resetLocalState = useCallback(() => {
        setOpen(null); setCategories([]); setBaseline(new Map()); setSelectedTattoos([]); setBaselineTattoos([]); setOutfits([]); setActiveGroup("tops")
        setHair(null); setHead(null); setBaselineHair(null); setBaselineHead(null)
        setSelectedKey(undefined); setZone("full"); setError(undefined); setSaveName("")
        setOutfitsExpanded(false); setConfirmPending(false); setOwnedSnapshot(false)
    }, [])

    useNuiEvent<OpenPayload>("qbclothing:nui:open", (payload) => {
        // Start from the same clean slate as a close, then layer the
        // payload-derived fields on top -- keeps the "what does a fresh
        // session look like" defaults defined in exactly one place.
        resetLocalState()
        setOpen(payload)
        setCategories(payload.categories)
        setSelectedTattoos(payload.selectedTattoos ?? [])
        setBaselineTattoos(payload.selectedTattoos ?? [])
        setHair(payload.hair ?? null)
        setHead(payload.head ?? null)
        setBaselineHead(payload.head ?? null)
        setBaselineHair(payload.hair ? { color: payload.hair.color, highlight: payload.hair.highlight } : null)
        setBaseline(new Map(payload.categories.map((item) => [itemKey(item), { drawable: item.drawable, texture: item.texture }])))
        setOutfits(payload.outfits ?? [])
        const groups = new Set(payload.categories.map((item) => item.category))
        const firstGroup = GROUP_ORDER.find((group) => groups.has(group)) ?? "tops"
        setActiveGroup(firstGroup)
        const firstItem = payload.categories.find((item) => item.category === firstGroup)
        setSelectedKey(firstItem ? itemKey(firstItem) : undefined)
    })

    useNuiEvent<OutfitSummary[]>("qbclothing:nui:outfits", (list) => setOutfits(list ?? []))
    useNuiEvent<ErrorPayload>("qbclothing:nui:error", ({ message }) => { setConfirmPending(false); setError(message) })
    useNuiEvent<object>("qbclothing:nui:close", () => resetLocalState())

    const groupsPresent = useMemo(() => new Set(categories.map((item) => item.category)), [categories])
    const itemsInActiveGroup = useMemo(() => categories.filter((item) => item.category === activeGroup), [categories, activeGroup])
    const selectedItem = useMemo(() => categories.find((item) => itemKey(item) === selectedKey), [categories, selectedKey])
    const overlays = enabledOverlays(selectedItem, head)

    const changedTotal = useMemo(() => {
        if (!open || open.free || ownedSnapshot) return 0
        const changedGroups = new Set<CategoryGroup>()
        for (const item of categories) {
            const base = baseline.get(itemKey(item))
            if (!base || base.drawable !== item.drawable || base.texture !== item.texture) changedGroups.add(item.category)
        }
        // Hair colour is priced as part of the hair component's own category,
        // exactly as the server's priceDiff marks it -- a barber visit that
        // only recoloured must not read as free here and then charge on
        // confirm.
        if (baselineHair && hair && (hair.color !== baselineHair.color || hair.highlight !== baselineHair.highlight)) {
            changedGroups.add("body")
        }
        // Eyebrow/facial-hair edits are priced with the hair category, as the server does.
        if (baselineHead && head && HEAD_OVERLAYS.some((overlay) =>
            head[overlay.style] !== baselineHead[overlay.style]
            || head[overlay.opacity] !== baselineHead[overlay.opacity]
            || head[overlay.color] !== baselineHead[overlay.color])) {
            changedGroups.add("body")
        }
        let total = 0
        for (const group of changedGroups) total += priceOf(open.prices, group)
        const baselineTattooSet = new Set(baselineTattoos)
        for (const id of selectedTattoos) {
            if (!baselineTattooSet.has(id)) total += open.tattoos.find((tattoo) => tattoo.id === id)?.price ?? 0
        }
        return total
    }, [baseline, baselineHair, baselineHead, baselineTattoos, categories, hair, head, open, ownedSnapshot, selectedTattoos])

    const selectGroup = useCallback((group: CategoryGroup) => {
        setActiveGroup(group)
        const first = categories.find((item) => item.category === group)
        setSelectedKey(first ? itemKey(first) : undefined)
    }, [categories])

    const applyVariationResponse = useCallback((target: ClothingCategoryItem, response: SetVariationResponse) => {
        if (!response.ok) return
        setOwnedSnapshot(false) // any manual edit means this is no longer exactly the outfit that was loaded
        setCategories((current) => current.map((item) => item.kind === target.kind && item.id === target.id
            ? {
                ...item,
                drawable: response.drawable ?? item.drawable,
                texture: response.texture ?? item.texture,
                drawableCount: response.drawableCount ?? item.drawableCount,
                textureCount: response.textureCount ?? item.textureCount,
            }
            : item))
    }, [])

    const setVariation = useCallback(async (target: ClothingCategoryItem, next: { drawable: number; texture: number }) => {
        const response = await sendIntent<SetVariationPayload, SetVariationResponse>("qbclothing:nui:setVariation", {
            kind: target.kind, id: target.id, drawable: next.drawable, texture: next.texture,
        })
        applyVariationResponse(target, response)
    }, [applyVariationResponse])

    const setHairColor = useCallback(async (next: { color: number; highlight: number }) => {
        const response = await sendIntent<SetHairColorPayload, SetHairColorResponse>("qbclothing:nui:setHairColor", next)
        if (!response.ok) return
        setOwnedSnapshot(false)
        setHair((current) => current && {
            ...current,
            color: response.color ?? current.color,
            highlight: response.highlight ?? current.highlight,
        })
    }, [])

    const setHeadAppearance = useCallback(async (next: HeadValues) => {
        const response = await sendIntent<SetHeadPayload, SetHeadResponse>("qbclothing:nui:setHead", next)
        if (response.ok && response.head) {
            const confirmed = response.head
            setHead((current) => current && mergeHeadValues(current, confirmed))
            setOwnedSnapshot(false)
        }
    }, [])

    const changeZone = useCallback((next: Zone) => {
        setZone(next)
        void sendIntent<CameraPayload, object>("qbclothing:nui:camera", { zone: next })
    }, [])

    const wearOutfit = useCallback(async (id: number) => {
        const response = await sendIntent<{ id: number }, LoadOutfitResponse>("qbclothing:nui:loadOutfit", { id })
        if (response.ok && response.categories) {
            setCategories(response.categories)
            setSelectedTattoos(response.selectedTattoos ?? [])
            if (response.hair) setHair(response.hair)
            setHead(response.head ?? null)
            setOwnedSnapshot(true) // exactly what's saved -- free to confirm as-is until edited
            const groups = new Set(response.categories.map((item) => item.category))
            const nextGroup = groups.has(activeGroup) ? activeGroup : (GROUP_ORDER.find((group) => groups.has(group)) ?? activeGroup)
            setActiveGroup(nextGroup)
            const first = response.categories.find((item) => item.category === nextGroup)
            setSelectedKey(first ? itemKey(first) : undefined)
        }
    }, [activeGroup])

    const toggleTattoo = useCallback(async (id: string) => {
        // Jump the camera to wherever this tattoo actually sits -- the
        // toolbar's zoom otherwise stays wherever it was last left (often
        // "Face" or "Full body"), so a Torso/Arms tattoo could be toggled
        // without ever being in frame to see the result.
        const group = open?.tattoos.find((tattoo) => tattoo.id === id)?.group
        if (group && TATTOO_ZONE[group]) changeZone(TATTOO_ZONE[group])

        const next = selectedTattoos.includes(id) ? selectedTattoos.filter((value) => value !== id) : [...selectedTattoos, id]
        const response = await sendIntent<{ tattoos: string[] }, SetTattoosResponse>("qbclothing:nui:setTattoos", { tattoos: next })
        if (response.ok && response.tattoos) {
            setOwnedSnapshot(false)
            setSelectedTattoos(response.tattoos)
        }
    }, [selectedTattoos, open, changeZone])

    const deleteOutfit = useCallback((id: number) => {
        void sendIntent<{ id: number }, object>("qbclothing:nui:deleteOutfit", { id })
    }, [])

    const confirm = useCallback(async () => {
        setConfirmPending(true)
        const trimmed = saveName.trim()
        const response = await sendIntent<ConfirmPayload, ConfirmResponse>("qbclothing:nui:confirm", trimmed ? { saveName: trimmed } : {})
        if (!response.ok) setConfirmPending(false)
        // On success, the session actually ends via the async qbclothing:nui:close message.
    }, [saveName])

    const cancel = useCallback(() => {
        void sendIntent<object, CancelResponse>("qbclothing:nui:cancel", {})
    }, [])

    useEffect(() => {
        const onKey = (event: KeyboardEvent) => {
            if (event.key === "Escape" && open && !open.mandatory) cancel()
        }
        window.addEventListener("keydown", onKey)
        return () => window.removeEventListener("keydown", onKey)
    }, [cancel, open])

    if (!open) return import.meta.env.DEV ? <button className="dev-launch" onClick={openDevHarness}>Open clothing UI harness</button> : null

    const copy = headlineCopy(open.mode, open.shopLabel, open.service)

    return <main className="clothing-shell">
        <Viewport onRotate={rotate} onZoom={zoom} />

        <div className="headline">
            {copy.badge && <span className="shop-badge">{copy.badge}</span>}
            <h1>{copy.title}</h1>
            <p>{copy.sub}</p>
        </div>

        <ZoneToolbar zone={zone} onSelect={changeZone} />

        {error && <div className="error-banner" role="alert">
            <CircleAlert size={16} />
            <span>{error}</span>
            <button type="button" aria-label="Dismiss error" onClick={() => setError(undefined)}><X size={14} /></button>
        </div>}

        <div className="rail rail-left">
            {groupsPresent.size > 0 && <div className="panel panel-pad">
                <p className="section-title">Categories</p>
                <CategoryTabs active={activeGroup} groups={groupsPresent} onSelect={selectGroup} />
            </div>}
            <TattooPanel tattoos={open.tattoos} selected={selectedTattoos} onToggle={(id) => void toggleTattoo(id)} />
            <OutfitsPanel
                outfits={outfits}
                expanded={outfitsExpanded}
                onToggle={() => setOutfitsExpanded((value) => !value)}
                onWear={(id) => void wearOutfit(id)}
                onDelete={deleteOutfit}
            />
        </div>

        {/* A tattoo-only session (Config.services.tattoo has no components/props)
            sends an empty `categories` list -- groupsPresent is then empty and
            activeGroup never moves off its "tops" default, which would
            otherwise show a "Tops" header over a permanently empty list. */}
        {groupsPresent.size > 0 && <div className="rail rail-right">
            <div className="panel panel-pad">
                <p className="section-title">{GROUP_LABEL[activeGroup]}</p>
                <ItemList items={itemsInActiveGroup} selectedKey={selectedKey} onSelect={(item) => setSelectedKey(itemKey(item))} />
            </div>
            <div className="panel panel-pad">
                <VariationDetail
                    item={selectedItem}
                    onChange={(next) => selectedItem && void setVariation(selectedItem, next)}
                    onClear={() => selectedItem && void setVariation(selectedItem, { drawable: -1, texture: 0 })}
                />
            </div>
            {/* Hair colour is a property of the hair component, so it appears
                with that component and nowhere else. `hair` itself is already
                null for any service that cannot edit component 2, so a
                clothing shop never renders these at all. */}
            {hair && selectedItem?.kind === "component" && selectedItem.id === HAIR_COMPONENT_ID && (
                <HairColorPanel hair={hair} onChange={(next) => void setHairColor(next)} />
            )}
            {/* Each head panel belongs to one Style item (src/lib/panels.ts), not
                to the whole Style group, so Mask no longer shows Face & Skin. */}
            {head && showFaceSkinPanel(selectedItem, head) && <FaceSkinPanel head={head} onChange={(next) => void setHeadAppearance(next)} />}
            {head && <HeadOverlayPanel head={head} overlays={overlays} palette={hair?.palette ?? []} onChange={(next) => void setHeadAppearance(next)} />}
        </div>}

        <div className="bottom-bar">
            <label className="save-field">
                <Save size={15} />
                <input value={saveName} onChange={(event) => setSaveName(event.target.value)} placeholder="Name this look" maxLength={40} />
            </label>
            {(open.mode === "shop" || open.mode === "wardrobe") && <div className="price-total">
                <span className="price-label">Total</span>
                <span className="price-value">${changedTotal.toLocaleString()}</span>
            </div>}
            {!open.mandatory && <button type="button" className="btn btn-ghost" onClick={cancel} disabled={confirmPending}>Cancel</button>}
            <button type="button" className="btn btn-primary" onClick={() => void confirm()} disabled={confirmPending}>
                {confirmPending ? "Working..." : confirmLabel(open.mode, changedTotal)}
            </button>
        </div>
    </main>
}

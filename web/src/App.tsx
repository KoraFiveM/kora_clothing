import { ChevronDown, Copy, Minus, Mouse, Move, ChevronLeft, ChevronRight, CircleAlert, Footprints, Gem, Glasses, Maximize2, PersonStanding, Save, Shirt, Smile, Trash2, User, UserRound, X } from "lucide-react"
import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import { openDevHarness } from "@/lib/dev"
import { listenForDragEnd } from "@/lib/dragGuard"
import { sendIntent } from "@/lib/nui"
import { hintEnabled, hintVisible, startHintTimer } from "@/lib/hint"
import { scrollRailWithWheel } from "@/lib/railWheel"
import { resolveStepEdit } from "@/lib/stepper"
import { countOf, duplicateTattoo, instanceLabel, instancePrice, removeTattooInstance, stackLimit, tattooTotal, toggleTattoo as toggleTattooId } from "@/lib/tattoos"
import { activeParts, allUndressed, toggleAll, togglePart, undressVisible } from "@/lib/undress"
import type { SetUndressPayload, SetUndressResponse, UndressPart } from "@/lib/undress"
import { listenForLockChange, releaseRotateLock, requestRotateLock } from "@/lib/pointerLock"
import { RotateDrag } from "@/lib/rotateDrag"
import type { DragIO, RotateMode } from "@/lib/rotateDrag"
import type {
    CameraPayload,
    CategoryCameraPayload,
    CategoryCameraResponse,
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
    TattooStacking,
    ZoomPayload,
} from "@/lib/types"
import { enabledOverlays, HAIR_COMPONENT_ID, HEAD_OVERLAYS, initialSelection, mergeHeadValues, overlayColorEditable, showFaceSkinPanel } from "@/lib/panels"
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
function useRotate(): DragIO {
    const pending = useRef(0)
    const frame = useRef<number | null>(null)
    const flush = useCallback(() => {
        frame.current = null
        if (pending.current === 0) return
        const deltaDeg = pending.current
        pending.current = 0
        void sendIntent<RotatePayload, object>("qbclothing:nui:rotate", { deltaDeg })
    }, [])
    const rotate = useCallback((delta: number) => {
        pending.current += delta
        if (frame.current === null) frame.current = requestAnimationFrame(flush)
    }, [flush])
    // Drag over: drop whatever has not been sent so nothing lands after the
    // end, then tell Lua to settle the camera where it is.
    const end = useCallback(() => {
        pending.current = 0
        if (frame.current !== null) { cancelAnimationFrame(frame.current); frame.current = null }
        void sendIntent<object, object>("qbclothing:nui:rotateEnd", {})
    }, [])
    // Config.rotateMode = "controls": Lua takes over the mouse until the button is released.
    const start = useCallback(async (button: number, x: number, y: number) => {
        const response = await sendIntent<{ button: number; x: number; y: number }, { active?: boolean }>("qbclothing:nui:rotateStart", { button, x, y })
        return response?.active === true
    }, [])
    // Config.rotateMode = "recenter": Lua moves the cursor back to the screen centre.
    const recenter = useCallback(() => { void sendIntent<object, object>("qbclothing:nui:recenter", {}) }, [])
    return useMemo(() => ({ rotate, end, start, recenter }), [rotate, end, start, recenter])
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

function Viewport({ io, onZoom, onInteract, mode, pointerLock, dragGuard, rightButton, invert, edgeMargin }: {
    io: DragIO
    onZoom: (notches: number) => void
    /** First real rotate or zoom: the player has found the controls. */
    onInteract: () => void
    mode: RotateMode
    /** Config.rotatePointerLock; only used in "pointer" mode. */
    pointerLock: boolean
    dragGuard: boolean
    rightButton: boolean
    invert: boolean
    edgeMargin?: number
}) {
    const options = { mode, degPerPixel: DRAG_ROTATION_DEG_PER_PIXEL * (invert ? -1 : 1), guard: dragGuard, rightButton, edgeMargin }
    const dragRef = useRef<RotateDrag | null>(null)
    if (!dragRef.current) dragRef.current = new RotateDrag(io, options)
    const drag = dragRef.current
    // Checked on every render so a changed setting applies on the next drag.
    drag.setOptions(options)
    const locked = useRef(false)
    const unlock = useCallback(() => {
        if (!locked.current) return
        locked.current = false
        releaseRotateLock(document)
    }, [])
    // Escape and unmount end a drag unconditionally; blur, leaving the window and a
    // lost capture go through lost(), which Lua-owned (controls mode) drags ignore
    // because the focus switch itself blurs the page.
    useEffect(() => {
        const onKey = (event: KeyboardEvent) => { if (event.key === "Escape") { drag.cancel(); unlock() } }
        const onBlur = () => { drag.lost(true); unlock() }
        window.addEventListener("keydown", onKey)
        window.addEventListener("blur", onBlur)
        const stopGuard = dragGuard ? listenForDragEnd(window, document, () => { drag.lost(); unlock() }) : () => {}
        // Lock lost mid-drag ends the drag; a refused lock keeps the plain drag.
        const stopLock = listenForLockChange(document, () => { if (locked.current) { drag.cancel(); unlock() } }, () => { locked.current = false })
        return () => {
            window.removeEventListener("keydown", onKey)
            window.removeEventListener("blur", onBlur)
            stopGuard(); stopLock()
            drag.cancel(); unlock()
        }
    }, [drag, dragGuard, unlock])
    // Lua ended a controls-mode drag (button released, safety stop): nothing more to send.
    useNuiEvent<object>("qbclothing:nui:rotateStopped", () => { drag.luaStopped(); unlock() })
    const sample = (event: { clientX: number; clientY: number; button?: number; buttons?: number; movementX?: number }) => ({
        button: event.button, buttons: event.buttons, movementX: event.movementX,
        clientX: event.clientX, clientY: event.clientY, width: window.innerWidth, height: window.innerHeight,
    })
    // Moves and the release are listened to on the window, not the viewport, so a drag
    // keeps turning the character over panels and rails, and outside the page, until the
    // button comes up. Pointer capture on the viewport (set on press) keeps events
    // coming when the cursor leaves the window.
    const viewport = useRef<HTMLDivElement | null>(null)
    useEffect(() => {
        const onMove = (event: PointerEvent) => {
            if (drag.move(sample(event))) onInteract()
            if (!drag.dragging) unlock()
        }
        const release = (event: MouseEvent | PointerEvent) => {
            drag.up()
            unlock()
            const element = viewport.current
            if (element && "pointerId" in event && element.hasPointerCapture?.(event.pointerId)) element.releasePointerCapture(event.pointerId)
        }
        const onCancel = () => { drag.lost(); unlock() }
        window.addEventListener("pointermove", onMove)
        window.addEventListener("pointerup", release)
        window.addEventListener("mouseup", release)
        window.addEventListener("pointercancel", onCancel)
        return () => {
            window.removeEventListener("pointermove", onMove)
            window.removeEventListener("pointerup", release)
            window.removeEventListener("mouseup", release)
            window.removeEventListener("pointercancel", onCancel)
            drag.cancel()
            unlock()
        }
    }, [drag, unlock, onInteract])
    return <div
        ref={viewport}
        className="clothing-viewport"
        onContextMenu={(event) => event.preventDefault()}
        onPointerDown={(event) => {
            if (!drag.down(sample(event.nativeEvent))) return
            event.currentTarget.setPointerCapture(event.pointerId)
            if (mode === "pointer") locked.current = requestRotateLock(event.currentTarget, pointerLock)
        }}
        onLostPointerCapture={() => { if (dragGuard) { drag.lost(); unlock() } }}
        onWheel={(event) => {
            // Over the right rail (its gaps are click-through) the wheel scrolls the menu.
            if (scrollRailWithWheel(document.querySelector<HTMLElement>(".rail-right"), event)) return
            onZoom(Math.sign(event.deltaY)); onInteract()
        }}
        aria-hidden="true"
    />
}

/** Small, muted, click-through reminder that the character can be dragged and
 * zoomed. It fades rather than unmounts so the layout never shifts. */
function ControlsHint({ visible }: { visible: boolean }) {
    return <div className={visible ? "controls-hint" : "controls-hint is-hidden"} aria-hidden="true">
        <span><Move size={13} />Drag to rotate</span>
        <span className="controls-hint-dot">·</span>
        <span><Mouse size={13} />Scroll to zoom</span>
    </div>
}

/** Icon per part id from Config.tattoo.undress.parts; a custom part gets the generic one. */
const UNDRESS_ICON: Record<string, typeof Shirt> = { top: Shirt, legs: PersonStanding, shoes: Footprints, headwear: Glasses }

function UndressToolbar({ parts, active, onToggle, onToggleAll }: {
    parts: UndressPart[]
    active: string[]
    onToggle: (part: string) => void
    onToggleAll: () => void
}) {
    const everything = allUndressed(parts, active)
    return <div className="undress-toolbar" role="group" aria-label="Preview clothing">
        {parts.map((part) => {
            const Icon = UNDRESS_ICON[part.id] ?? Shirt
            const bare = active.includes(part.id)
            return <button key={part.id} type="button" title={bare ? `Put on: ${part.label}` : `Take off: ${part.label}`} aria-label={part.label} aria-pressed={bare} onClick={() => onToggle(part.id)}>
                <Icon size={16} />
            </button>
        })}
        <button type="button" className="undress-all" aria-label={everything ? "Dress" : "Undress all"} onClick={onToggleAll}>
            <UserRound size={16} /><span>{everything ? "Dress" : "Undress all"}</span>
        </button>
    </div>
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
    const clearable = item.kind === "prop" && item.clearable === true
    const canPrevDrawable = item.kind === "prop" && item.clearable ? item.drawable > -1 : item.drawable > 0
    const canNextDrawable = item.drawable < item.drawableCount - 1
    const canPrevTexture = !removed && item.texture > 0
    const canNextTexture = !removed && item.texture < item.textureCount - 1

    return <div>
        <h3 className="detail-title">{item.label}</h3>
        <p className="detail-sub">{item.kind === "component" ? "Clothing item" : "Accessory"}</p>

        <Stepper
            label="Style"
            text={removed ? "None" : `${item.drawable + 1} / ${item.drawableCount}`}
            canPrev={canPrevDrawable} canNext={canNextDrawable}
            onPrev={() => onChange({ drawable: item.drawable - 1, texture: 0 })}
            onNext={() => onChange({ drawable: item.drawable + 1, texture: 0 })}
            typed={{ value: removed ? 0 : item.drawable + 1, min: clearable ? 0 : 1, max: item.drawableCount, onCommit: (value) => onChange({ drawable: value - 1, texture: 0 }) }}
        />

        <Stepper
            label="Color"
            text={removed ? "--" : `${item.texture + 1} / ${Math.max(item.textureCount, 1)}`}
            canPrev={canPrevTexture} canNext={canNextTexture}
            onPrev={() => onChange({ drawable: item.drawable, texture: item.texture - 1 })}
            onNext={() => onChange({ drawable: item.drawable, texture: item.texture + 1 })}
            typed={removed ? undefined : { value: item.texture + 1, min: 1, max: Math.max(item.textureCount, 1), onCommit: (value) => onChange({ drawable: item.drawable, texture: value - 1 }) }}
        />

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
function HairColorGrid({ label, palette, value, onSelect, onMatchHair }: {
    label: string
    palette: HairSwatch[]
    value: number
    onSelect: (index: number) => void
    /** Offered by overlays that can fall back to the hair colour (value -1). */
    onMatchHair?: () => void
}) {
    return <div className="swatch-block">
        <p className="swatch-label">{label}</p>
        {onMatchHair && <button type="button" className="match-hair" aria-pressed={value < 0} onClick={onMatchHair}>Match hair colour</button>}
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

/** The "n / max" readout. With `typed` the number is an input: click it, type a
 * value, Enter or click away to apply, Escape to revert. Without it (None, or
 * nothing to choose) the text is shown as before. */
interface TypedStep {
    /** Shown value, 1-based (0 for "None"). */
    value: number
    min: number
    max: number
    onCommit: (value: number) => void
}

function StepValue({ text, typed }: { text: string; typed?: TypedStep }) {
    const [draft, setDraft] = useState<string | null>(null)
    // Enter commits and then blurs; the ref stops that blur committing twice.
    const editing = useRef(false)
    if (!typed) return <span>{text}</span>

    const finish = (end: "enter" | "blur" | "escape") => {
        if (!editing.current) return
        editing.current = false
        const next = resolveStepEdit(draft ?? "", end, { min: typed.min, max: typed.max, current: typed.value })
        setDraft(null)
        if (next !== null) typed.onCommit(next)
    }

    return <span className="step-value">
        <input
            className="step-input"
            type="text"
            inputMode="numeric"
            maxLength={6}
            aria-label={`${text} (type a number)`}
            value={draft ?? String(typed.value)}
            style={{ width: `${Math.max(2, String(typed.max).length)}ch` }}
            onFocus={(event) => { editing.current = true; setDraft(String(typed.value)); event.currentTarget.select() }}
            onChange={(event) => setDraft(event.target.value)}
            onBlur={() => finish("blur")}
            onKeyDown={(event) => {
                // Typing must never reach the menu's own shortcuts (Escape closes it).
                event.stopPropagation()
                if (event.key === "Enter") { finish("enter"); event.currentTarget.blur() }
                else if (event.key === "Escape") { finish("escape"); event.currentTarget.blur() }
            }}
            onKeyUp={(event) => event.stopPropagation()}
        />
        <span className="step-max">/ {typed.max}</span>
    </span>
}

function Stepper({ label, text, canPrev, canNext, onPrev, onNext, typed }: {
    label: string
    text: string
    canPrev: boolean
    canNext: boolean
    onPrev: () => void
    onNext: () => void
    typed?: TypedStep
}) {
    return <div className="stepper">
        <label>{label}</label>
        <button type="button" className="step-btn" aria-label={`Previous ${label}`} disabled={!canPrev} onClick={onPrev}><ChevronLeft size={16} /></button>
        <StepValue text={text} typed={typed} />
        <button type="button" className="step-btn" aria-label={`Next ${label}`} disabled={!canNext} onClick={onNext}><ChevronRight size={16} /></button>
    </div>
}

/** Skin tone, shown with the Face item only. */
function FaceSkinPanel({ head, onChange }: { head: HeadPayload; onChange: (next: HeadValues) => void }) {
    return <div className="panel panel-pad head-panel">
        <p className="section-title">Face & Skin</p>
        <Stepper
            label="Skin tone" text={`${head.skinTone + 1} / 46`}
            typed={{ value: head.skinTone + 1, min: 1, max: 46, onCommit: (value) => onChange({ ...head, skinTone: value - 1 }) }}
            canPrev={head.skinTone > 0} canNext={head.skinTone < 45}
            onPrev={() => onChange({ ...head, skinTone: head.skinTone - 1 })} onNext={() => onChange({ ...head, skinTone: head.skinTone + 1 })}
        />
    </div>
}

const OPACITY_STEP = 0.1

/** Style, opacity and colour for each overlay the server allows here, shown
 * with the Hair item beside the hair colour. Colour reuses the hair palette but
 * is its own choice per overlay; with none selected (or Match hair colour) the
 * overlay follows the hair colour. Eyebrows hide the palette when the server
 * locks them to the hair (Config.headOverlays.eyebrows.followHairColor). */
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
                    typed={{ value: style + 1, min: 0, max: overlay.maxStyle + 1, onCommit: (value) => onChange({ ...head, [overlay.style]: value - 1 }) }}
                    canPrev={style > -1} canNext={style < overlay.maxStyle}
                    onPrev={() => onChange({ ...head, [overlay.style]: style - 1 })} onNext={() => onChange({ ...head, [overlay.style]: style + 1 })}
                />
                <Stepper
                    label={`${overlay.label} opacity`} text={`${Math.round(opacity * 100)}%`}
                    canPrev={opacity > 0} canNext={opacity < 1}
                    onPrev={() => onChange({ ...head, [overlay.opacity]: Math.max(0, Math.round((opacity - OPACITY_STEP) * 100) / 100) })}
                    onNext={() => onChange({ ...head, [overlay.opacity]: Math.min(1, Math.round((opacity + OPACITY_STEP) * 100) / 100) })}
                />
                {style >= 0 && palette.length > 0 && overlayColorEditable(head, overlay.key) && <HairColorGrid
                    label={`${overlay.label} colour`} palette={palette} value={head[overlay.color]}
                    onSelect={(index) => onChange({ ...head, [overlay.color]: index })}
                    onMatchHair={() => onChange({ ...head, [overlay.color]: -1 })}
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

function TattooPanel({ tattoos, selected, stacking, onToggle, onDuplicate, onRemoveOne }: {
    tattoos: TattooItem[]; selected: string[]; stacking?: TattooStacking
    onToggle: (id: string) => void; onDuplicate: (id: string) => void; onRemoveOne: (id: string) => void
}) {
    if (tattoos.length === 0) return null
    const limit = stackLimit(stacking)
    return <div className="panel panel-pad tattoo-panel">
        <p className="section-title">Tattoos</p>
        <div className="tattoo-list">
            {tattoos.map((tattoo) => {
                const count = countOf(selected, tattoo.id)
                const canStack = limit > 1 && count > 0
                return <div key={tattoo.id} className="tattoo-row">
                    <input type="checkbox" checked={count > 0} onChange={() => onToggle(tattoo.id)} aria-label={tattoo.label} />
                    <span className="tattoo-copy"><strong>{instanceLabel(tattoo.label, count)}</strong><small>{tattoo.group}</small></span>
                    {canStack && count > 1 && <button type="button" className="tattoo-btn" title="Remove one instance" aria-label={`Remove one ${tattoo.label}`} onClick={() => onRemoveOne(tattoo.id)}><Minus size={12} /></button>}
                    {canStack && <button type="button" className="tattoo-btn" disabled={count >= limit}
                        title={count >= limit ? `Maximum ${limit} instances` : `Add another (+$${instancePrice(tattoo.price, count + 1, stacking)})`}
                        aria-label={`Duplicate ${tattoo.label}`} onClick={() => onDuplicate(tattoo.id)}><Copy size={12} /></button>}
                    <span className="tattoo-price">${tattoo.price}</span>
                </div>
            })}
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
    const [undressActive, setUndressActive] = useState<string[]>([])
    const [error, setError] = useState<string>()
    const [saveName, setSaveName] = useState("")
    const [outfitsExpanded, setOutfitsExpanded] = useState(false)
    const [confirmPending, setConfirmPending] = useState(false)
    const [hintDismissed, setHintDismissed] = useState(false)

    const rotateIO = useRotate()
    const zoom = useZoom()

    const resetLocalState = useCallback(() => {
        setOpen(null); setCategories([]); setBaseline(new Map()); setSelectedTattoos([]); setBaselineTattoos([]); setOutfits([]); setActiveGroup("tops")
        setHair(null); setHead(null); setBaselineHair(null); setBaselineHead(null)
        setSelectedKey(undefined); setZone("full"); setUndressActive([]); setError(undefined); setSaveName("")
        setOutfitsExpanded(false); setConfirmPending(false); setOwnedSnapshot(false); setHintDismissed(false)
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
        setUndressActive(activeParts(payload.undress?.active))
        setBaselineHair(payload.hair ? { color: payload.hair.color, highlight: payload.hair.highlight } : null)
        setBaseline(new Map(payload.categories.map((item) => [itemKey(item), { drawable: item.drawable, texture: item.texture }])))
        setOutfits(payload.outfits ?? [])
        const start = initialSelection(payload.categories, GROUP_ORDER, payload.head?.skinToneEditable === true, payload.creatorOpensOnHair)
        setActiveGroup((start.group as CategoryGroup | undefined) ?? "tops")
        setSelectedKey(start.item ? itemKey(start.item) : undefined)
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
        total += tattooTotal(selectedTattoos, baselineTattoos, open.tattoos, open.tattooStacking)
        return total
    }, [baseline, baselineHair, baselineHead, baselineTattoos, categories, hair, head, open, ownedSnapshot, selectedTattoos])

    // The game resolves the framing (Config.camera.categoryZones, and whether
    // to move the camera at all) and reports the zone now in effect.
    const frameCategory = useCallback(async (category: string) => {
        const response = await sendIntent<CategoryCameraPayload, CategoryCameraResponse>("qbclothing:nui:camera", { category })
        if (response.zone) setZone(response.zone)
    }, [])

    const selectGroup = useCallback((group: CategoryGroup) => {
        setActiveGroup(group)
        const first = categories.find((item) => item.category === group)
        setSelectedKey(first ? itemKey(first) : undefined)
        frameCategory(group)
    }, [categories, frameCategory])

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

    // Preview-only: the game bares or restores the parts on the local ped and
    // answers with what is bared now; nothing here reaches the saved outfit.
    const sendUndress = useCallback(async (request: SetUndressPayload) => {
        const response = await sendIntent<SetUndressPayload, SetUndressResponse>("qbclothing:nui:setUndress", request)
        if (response.ok) setUndressActive(activeParts(response.active))
    }, [])

    const wearOutfit = useCallback(async (id: number) => {
        const response = await sendIntent<{ id: number }, LoadOutfitResponse>("qbclothing:nui:loadOutfit", { id })
        if (response.ok && response.categories) {
            setCategories(response.categories)
            setSelectedTattoos(response.selectedTattoos ?? [])
            if (response.hair) setHair(response.hair)
            setHead(response.head ?? null)
            if (response.undress) setUndressActive(activeParts(response.undress.active))
            setOwnedSnapshot(true) // exactly what's saved -- free to confirm as-is until edited
            const groups = new Set(response.categories.map((item) => item.category))
            const nextGroup = groups.has(activeGroup) ? activeGroup : (GROUP_ORDER.find((group) => groups.has(group)) ?? activeGroup)
            setActiveGroup(nextGroup)
            const first = response.categories.find((item) => item.category === nextGroup)
            setSelectedKey(first ? itemKey(first) : undefined)
        }
    }, [activeGroup])

    const changeTattoos = useCallback(async (id: string, change: (selected: string[]) => string[]) => {
        // Frame wherever this tattoo actually sits -- the toolbar's zoom
        // otherwise stays wherever it was last left, so a Torso/Arms tattoo
        // could be toggled without ever being in frame to see the result.
        const group = open?.tattoos.find((tattoo) => tattoo.id === id)?.group
        if (group) void frameCategory(group)

        const next = change(selectedTattoos)
        if (next === selectedTattoos) return
        const response = await sendIntent<{ tattoos: string[] }, SetTattoosResponse>("qbclothing:nui:setTattoos", { tattoos: next })
        if (response.ok && response.tattoos) {
            setOwnedSnapshot(false)
            setSelectedTattoos(response.tattoos)
        }
    }, [selectedTattoos, open, frameCategory])

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

    // Fades out on its own if the player never touches the camera.
    const hintOn = open !== null && hintEnabled(open)
    useEffect(() => {
        if (!hintOn) return
        return startHintTimer(() => setHintDismissed(true))
    }, [hintOn, open])
    const dismissHint = useCallback(() => setHintDismissed(true), [])

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
        <Viewport io={rotateIO} onZoom={zoom} onInteract={dismissHint} mode={open.rotateMode ?? "pointer"} pointerLock={open.rotatePointerLock === true} dragGuard={open.rotateDragGuard !== false} rightButton={open.rotateRightButton !== false} invert={open.rotateInvert === true} edgeMargin={open.rotateRecenterEdge} />

        <div className="headline">
            {copy.badge && <span className="shop-badge">{copy.badge}</span>}
            <h1>{copy.title}</h1>
            <p>{copy.sub}</p>
        </div>

        <ZoneToolbar zone={zone} onSelect={changeZone} />

        {undressVisible(open.undress) && <UndressToolbar
            parts={open.undress.parts}
            active={undressActive}
            onToggle={(part) => void sendUndress(togglePart(part, undressActive))}
            onToggleAll={() => void sendUndress(toggleAll(open.undress!.parts, undressActive))}
        />}

        <ControlsHint visible={hintVisible(hintOn, hintDismissed)} />

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
            <TattooPanel tattoos={open.tattoos} selected={selectedTattoos} stacking={open.tattooStacking}
                onToggle={(id) => void changeTattoos(id, (list) => toggleTattooId(list, id))}
                onDuplicate={(id) => void changeTattoos(id, (list) => duplicateTattoo(list, id, open.tattooStacking))}
                onRemoveOne={(id) => void changeTattoos(id, (list) => removeTattooInstance(list, id))} />
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

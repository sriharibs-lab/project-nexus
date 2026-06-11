# Nexus — design language & project memory

> This is my canonical design language. Apply it **by default** to every surface and
> every new element in this project (and carry it into my other projects). When I add a
> new control, menu, screen, or animation, it should already follow these rules without
> me re-asking. Reference implementation: `ui_kits/ios_app/` (`home.html` +
> `landing-app.jsx` / `landing-kit.jsx` / `landing-pieces.jsx`).

## 1. Material model — two layers, never mixed
- **Inline controls live ON a surface** (composer, cards, rows): solid/translucent fill
  with a **hairline border**, no glass, no heavy shadow. Quiet and legible.
- **Floating layers live ABOVE content** (all menus/popovers): **Liquid Glass** (§3).
  This is the Apple iOS 26 model — glass is the *functional floating layer*, not a
  decoration sprinkled on every button. Don't make inline buttons glass (it disappears
  on our near-white ground); don't make floating menus flat.

## 2. Palette — accent-free
- The **only** colour is the soft plum background bloom (`page` radial gradient).
  Everything else is ink / muted / faint / hairline — hierarchy from **weight + spacing**,
  not colour. Tokens in `lTheme()` (`landing-kit.jsx`).
- Exactly **one** ink-filled affordance per surface as the anchor (composer's audio
  button). If a surface seems to need a colour accent back, **flag it for review** first.

## 3. Liquid Glass (floating menus) — the material
Built as layered divs in `LiquidGlassCard` (`landing-app.jsx`). Back→front:
1. **Frost** — `backdrop-filter: blur(8px) saturate(195%) brightness(1.05)`. Translucent,
   lively, sees *through* to content (not milky). Adapts to whatever's behind it.
2. **Tint + gloss** — diagonal `linear-gradient(135deg, …)` white sheen (the reflection),
   brightest at the two corners, near-clear through the middle.
3. **Lens / chromatic edge** — inset shadows: bright top-left bevel + faint blue
   (`150,170,255`) bottom and faint pink (`255,150,205`) — fakes refraction/chromatic
   aberration. (Chrome rejects `backdrop-filter: url()`, so true SVG refraction is out —
   do NOT rely on it.)
4. **Specular rim** — crisp bright bevel `inset` highlights + soft inner glow.
5. Soft **float shadow** on the wrapper for depth (`0 22px 58px …`).
- Radius: **22–26**, generous and concentric.
- Liquid Glass *floats above* content — it gets a shadow. (This supersedes the old
  "menus are shadowless" note.)
- The scrim behind a menu is **transparent** — content outside the menu is **never
  dimmed or blurred**. Only the glass pane itself frosts what's directly behind it.

## 4. Bloom-morph — how every menu opens/closes
`BloomMenu` (`landing-app.jsx`). The menu **springs out of its anchor** and is **absorbed
back into it** on close:
- Surface `scale .12 → 1` on a **true-spring `linear()` easing** (`SPRING_LINEAR`, baked
  from a k=200 / c=15.5 / ζ≈0.55 sim — overshoots ~1.12). **Always CSS `linear()`, never
  a rAF JS spring** (rAF stalls when the frame backgrounds → menu gets stuck).
- Content fades in *after* the surface arrives (`opacity` delayed ~0.1s).
- Close reverses with a quick ease-in collapse (`.26s cubic-bezier(.4,0,.9,.35)`).
- **Corner pinning**: `transform-origin` + position pin the card's corner to the anchor's
  matching corner so it literally grows from the trigger. Avatar menu: card **top-right =
  avatar top-right** (`top:64,right:14`). Composer menus: **bottom-left**, blooming upward.
- The trigger that opens an *overlay covering itself* (the avatar) **hides instantly**
  (`opacity 0`) the moment the menu opens, so it never flashes on top during the bloom,
  and fades back with its bounce on close.

## 5. Menu content — no separators
- **No divider lines.** Hierarchy from a small uppercase `MenuCaption`, weight, and
  spacing. Rows are rounded hit areas (`MenuRow`, radius ~14) with a spring press.
- Keep menus short; nest secondary items inside (e.g. account menu = profile +
  **Account · Settings · Feedback**; everything else lives under Settings).

## 6. Motion everywhere
- **Press bounce on every tappable** — `Pressable` defaults to `scale ~.88–.97` with an
  ease-back spring (`SPRING_BOUNCE = cubic-bezier(.18,1.5,.4,1)`, ~.24s): presses *in*
  then springs slightly *past* and settles. Triggers that open a covering overlay can
  also replay the bounce on close (`nxPop` keyframe).
- **Segmented controls slide an animated thumb** between options (`Segmented`).
- **Pivot switch = horizontal swipe**: panes slide left/right (track translateX); the
  highlighter thumb slides in sync (`PivotSwipe`). Direction follows index order.
- Motion is **tunable via the Tweaks panel** (Transition slide/fade, Duration, Easing:
  spring / smooth / snappy) — see `home.html` `TWEAK_DEFAULTS`.
- Respect content visibility: entrance states must degrade to visible (print / reduced
  motion).

## 7. Layout / lists
- **Library items are full-width row cards** (`LCollectionCard`) with vertical gap — not a
  divided list. (We tried a divider list and reverted.)
- Stack overlays cleanly: the home screen is its own contained layer (`zIndex: 0`) so no
  page content can ever composite on top of an opening menu.

## 8. Surface specifics (Nexus iOS landing)
- Composer `+` = attach (Photos / Files / Camera). Tapping the composer text = the
  "Paste a URL" menu (Website / YouTube / Image / PDF — list expands).
- Pivots: **Recent / All** (pill tabs, swipe between). Search is parked for later.
- Audio glyph = four prominent rounded waveform bars, the single ink-filled control.

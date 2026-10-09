# Nexus brand — Echo Ember

Visual reference: `brand/kit.html` (open in a browser). This file holds the values to implement.

## Mark
Two inner arcs around a pearl node, plus a fainter outer arc pair. The arcs warm from plum to magenta to coral as they move outward.
- 48-unit grid: inner arcs 3.2 stroke, outer arcs 2.4 stroke at 60 % opacity (55 % on dark), node r 4.4, round caps.
- **≤ 24 px: use `mark-small-*`.** It has one ripple, a 4.5 stroke, a node r 5.5, and no shadow.
- Shadow (≥ 32 px only): light = Plum #5E3F9E at 30 %, y 1.2, blur 1.3 · dark = Magenta #E07BC0 at 55 % glow, blur 1.6. Never use a grey shadow.

## Colour
| Name | Hex | Use |
|---|---|---|
| Plum | #7054AB | Anchor · inner-arc start |
| Orchid | #9A5BB5 | Outer-arc start |
| Magenta | #B8569C | Gradient mid |
| Coral | #E8776A | Gradient end · icon glow |
| Night | #2E1D50 | App-icon ground |
| Deep night | #4D2E80 | App-icon ground end |
| Lilac | #B9A2EE | Dark-mode arc start |
| Peach | #FFA78A | Dark-mode arc end |
| Cream | #F7F3EC | App background |
| Ink | #130E1A | Text · one-colour mark |

Gradients:
- Ember light: 135° · #7054AB 0 → #B8569C 55 → #E8776A 100
- Ember dark: 135° · #B9A2EE 0 → #E07BC0 55 → #FFA78A 100
- Pearl node (radial, centre 35/30): #CDB8FF → #7E5CC4 45 → #4B2F86 (dark: #FFFFFF → #EFE6FF → #B9A2EE)
- Icon ground: 160° #2E1D50 → #4D2E80, plus a Coral radial glow at 42 % from the bottom-right (85/95), plus a white sheen at 28 % from the top-left

Colour lives only in the mark. The app UI stays Cream / Ink, as set out in DESIGN_LANGUAGE.md.

## Wordmark
Custom monoline geometric "Nexus". It is vector only, so never retype it in a font. The stroke is 1/7 of the cap height, with round caps and joins. Ink #130E1A on light, Mist #F4EFFA on dark.

## Rules
- Clear space = node diameter (x) on all sides.
- Minimum sizes: lockup 72 px / 18 mm · mark 16 px (small variant) · wordmark 48 px wide.
- Don't recolour (especially purple→blue), stretch, rotate, add glows, or place the colour mark on Plum. On busy grounds, use the icon tile.

## App icon (iOS)
- `brand/AppIcon/appicon-1024-{default,dark,tint}.png` → the Xcode AppIcon set's Any / Dark / Tinted slots (single-size 1024).
- The masters are full-bleed squares. Don't pre-round them; iOS applies the mask. The glyph sits in the central 62 %.
- Tinted is a grayscale glyph on black, which the system tints.

## Echo pulse (thinking state)
1.8 s loop, infinite. All transforms are centred on the node.
- Node: scale 1 → 1.22 (30 %) → 0.94 (60 %) → 1 · ease cubic-bezier(.45,0,.2,1)
- Inner arcs (delay .12 s) and outer arcs (delay .32 s): opacity .35 → 1 (35 %) → .5 (70 %) → .35; scale .94 → 1.04 → 1 · ease cubic-bezier(.3,0,.2,1)
- Ghost ripple (third arc pair, r ≈ 22.5, stroke 1.6, delay .5 s): opacity 0 → .5 (40 %) → 0 (80 %); scale .9 → 1.06
- Reduced motion: show the static mark.
- SwiftUI: use a `TimelineView` or keyframe animations with the curves above, not a physics spring.

## Files
- `brand/svg/`: `mark-*`, `mark-small-*`, `wordmark-*`, `lockup-horizontal-*`, `lockup-stacked-*` (light · dark · black · white), `appicon-1024-*`, `favicon.svg`, `avatar.svg`
- `brand/png/`: favicon-32, favicon-180 (apple-touch), avatar-400
- `brand/kit.html`: visual spec sheet

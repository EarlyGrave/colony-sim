# The board: structure, graph, phone layout

## Decision: one board of six "work details", not per-skill trees and not a web
Options weighed:
| option | pro | con for us |
|---|---|---|
| A. Per-skill trees (8 × ~10, like today's perks) | familiar, fits the perk panel | 8 more trees next to 8 perk trees = 16 tabs of nearly the same thing; no cross-skill builds; no place for Ledger (not a skill) |
| B. One PoE-style web (~80 nodes, pan/zoom) | builds, synergies, "a-ha" paths | unreadable at 390 px; pan+zoom fights the map camera gestures; every node needs a tooltip tap |
| **C. One board, six detail cards + seams** (chosen) | one currency, cross-detail builds via bridge keystones, each card is a phone screen, swipe between cards | needs one new panel (not the perk panel), 6 gates to explain |

C keeps the *economy* of B (shared marks, builds that straddle trades) with the *readability* of A. The six
details are the prison's work details — the fiction explains the gating ("you don't get Stacks marks until you've
worked the Stacks").

## Card layout (3 columns × 6 rows, all 78 nodes fit six screens + seams)
```
row 0            [m1 entry]            gate: skill >= 3 (Ledger: deed)
row 1     [m2]      [m3]      [m4]     each needs m1
row 2     [n1]      [m5]      [n2]     n1 <- m2, m5 <- m3, n2 <- m4
row 3     [m6]      [m7]      [m8]     m6 <- n1, m7 <- m5, m8 <- n2
row 4            [n3]                  n3 <- any of m6 m7 m8
row 5            [K detail keystone]   K <- 2 of n1 n2 n3
seam  ->  [bridge keystone]  <- next card    1 notable here + 1 notable there
```
`pos: [col,row]` is stored per node in the JSON (bridge keystones `[3,2]` = the seam, drawn between cards).
Node buttons are 64 px (touch rule), the card is 3 × 64 + gutters ≈ 260 px wide, 6 rows ≈ 420 px tall: fits
844 × 390 landscape with the colonist header on the left and the detail blurb at the bottom. Swipe or tap the
detail chips (Pit · Stacks · Shop · Yard · Infirmary · Ledger) to switch cards; the two seam keystones of the
current card are shown as half-diamonds on the card's left/right edge. Ring order: Pit → Stacks → Shop → Yard →
Infirmary → Ledger → Pit.

Tier is readable from the icon frame alone (no colour needed): minor = cut-corner box, notable = double square,
keystone = diamond. Colour = detail (Pit ochre, Stacks violet, Shop teal, Yard red, Infirmary green, Ledger gold,
bridges amber). Allocated nodes render the frame at full alpha, allocatable ones pulse, locked ones at 40 %.

## Graph rules (implemented in `PassiveTreeV2`)
- `requires_groups: [{any: [...], n: k}]` — every group must have ≥ k allocated members. Minors: one group
  `n: 1`; detail keystone: `n: 2` of the three notables; bridge: two groups `n: 1`.
- `gate` on entry nodes only: `{skills: {mining: 3, construction: 3}}` = *any* listed skill at that level
  (Pit and Yard have two), `{deed: d_first_installment}` for the Ledger.
- `can_allocate` reason codes, in check order: `unknown, allocated, locked, gate_skill, gate_deed, requires,
  keystone_limit, no_marks` — the UI maps each to one line of copy ("Needs Mining 3", "Two keystones already").
- `can_undo` → `unknown, not_allocated, grace, dependents`: free take-back within `undo_grace_ticks` (1800 = one
  day) as long as no allocated node would lose its requirements.
- Keystone cap `max_keystones` 2.
- Nothing is ever removed by the sim on its own (no "lost a keystone on injury"); traits own the scar layer.

## Why 8 / 3 / 1 and the ring
- 8 minors are the "numbers" (5–15 %); together they roughly equal one branch effect. They exist so a mark earned
  early is never wasted and so the entry gate (L3) matters immediately.
- 3 notables (20–50 %, sometimes two stats or a cost) are the mid-game decisions; two of them unlock the keystone,
  so a 9-mark inmate (m1 + two chains) sees the keystone light up and knows what the next 4 marks buy.
- 1 detail keystone + bridges on both sides: every detail has three "capstone" options, two of them shared with a
  neighbour, so the ring makes neighbour trades talk to each other (Yard + Infirmary = Walking Wounded; Ledger +
  Pit = Quota Hawk).

## Synergy table (what the board does with what exists)
| build | pieces | result |
|---|---|---|
| Clean refiner | Stacks n1 + n3 + Clean Hands (Pit bridge) | contamination per batch -45 % → capped at -40 % with perks; the "slow is safe" pillar build |
| Dirty refiner | Essence Lung + Tinkerer branch | waste -30 %, +20 % speed, mutation ×1.5 and the creatures come for *you* (threat_attract +30 % is per-colonist) |
| Quartermaster | Shop Reloader + Yard Count Shots + Armourer's Pride | ammo -50 % (ammo.gd pouch), gear wear -80 % cap |
| Trustee | Ledger K + Warden's Ear | installments -30 % → cap -40 %; Standing +25 % net; despair +30 % (he is hated) |
| Mule | Pit The Mule + Lifer's Back + Strong trait | carry ×2.75 of base; walks slow; hauler for the belt-less early game |
| Chaplain block | Chaplain + Even Keel + Calm Voice | one inmate's board: despair ×0.75, breaks -40 %, mood +8; XP -15 % |

# The board: structure, graph, phone layout (r2)

## Decision: one board of six "work details", not per-skill trees and not a web
Options weighed:
| option | pro | con for us |
|---|---|---|
| A. Per-skill trees (8 × ~10, like today's perks) | familiar, fits the perk panel | 8 more trees next to 8 perk trees = 16 tabs of nearly the same thing; no cross-skill builds; no place for Ledger (not a skill) |
| B. One PoE-style web (~90 nodes, pan/zoom) | builds, synergies, "a-ha" paths | unreadable at 390 px; pan+zoom fights the map camera gestures; every node needs a tooltip tap |
| **C. One board, six detail cards + seams** (chosen) | one currency, cross-detail builds via bridge keystones, each card is a phone screen, swipe between cards | needs one new panel (not the perk panel), 6 gates to explain |

C keeps the *economy* of B (shared marks, builds that straddle trades) with the *readability* of A. The six
details are the prison's work details — the fiction explains the gating ("you don't get Stacks marks until you've
worked the Stacks"). The owner's note (2026-10-21) confirms the board is **shared, not skill-bound**: a detail's
gate is the only place a skill matters; marks come from anywhere.

## Card layout (3 columns × 6 rows, 13 nodes per card; 90 nodes on six screens + seams)
```
row 0            [m1 entry]              gate: skill >= 3 (Ledger: deed)
row 1     [m2]      [m3]      [m4]       each needs m1
row 2     [n1]      [n2]      [n3]       n1 <- m2, n2 <- m3, n3 <- m4
row 3     [m5]       .        [m6]       m5 <- n1 or n2, m6 <- n2 or n3
row 4     [n4]       .        [n5]       n4 <- m5, n5 <- m6
row 5     [K1]       .        [K2]       K1 <- 2 of n1 n2 n4 (left school), K2 <- 2 of n2 n3 n5 (right school)
seam  ->  [bridge A] (row 2)  [bridge B] (row 4)  <- next card: 1 notable here + 1 notable there
```
`pos: [col,row]` is stored per node in the JSON (bridge keystones `[3,2]` and `[3,4]` = the seam, drawn between
cards as half-diamonds on the card's right edge; the previous card's two bridges appear on the left edge).
The centre column is the shared spine (m1, m3, n2): n2 belongs to both schools, so a 7-mark inmate
(m1 m2 n1 m3 n2) already sees K1 light up. Node buttons are 64 px (touch rule); the card is 3 × 64 + 2 × 12
gutters = 216 px wide and 6 × 64 + 5 × 8 = 424 px tall in UI units. At 844 × 390 landscape with
`content_scale_factor = DPR × 0.85` the UI viewport is ≈ 993 × 459 units on a DPR 3 phone, so the card plus the
colonist header (left, 240 px) and the seam strip (right, 72 px) fits with no vertical scroll; the detail blurb
goes under the header, not under the card. Swipe or tap the detail chips (Pit · Stacks · Shop · Yard ·
Infirmary · Ledger) to switch cards. Ring order: Pit → Stacks → Shop → Yard → Infirmary → Ledger → Pit.

Tier is readable from the icon frame alone (no colour needed): minor = cut-corner box, notable = double square,
keystone = **filled dark diamond with a 12 × 12 silhouette** (r2: bigger glyph, unique per keystone, so the two
keystones on a card and the seam badges are recognisable at 32 px). Colour = detail (Pit ochre, Stacks violet,
Shop teal, Yard red, Infirmary green, Ledger gold, bridges amber). Allocated nodes render the frame at full
alpha, allocatable ones pulse, locked ones at 40 %; an *excluded* keystone shows a struck-through diamond.

## Graph rules (implemented in `PassiveTreeV2`)
- `requires_groups: [{any: [...], n: k}]` — every group must have ≥ k allocated members. Minors: one group
  `n: 1` (m5/m6 list two notables); detail keystone: `n: 2` of its school's three notables; bridge: two groups
  `n: 1` over the five notables of each side.
- `gate` on entry nodes only: `{skills: {mining: 3, construction: 3}}` = *any* listed skill at that level
  (Pit and Yard have two), `{deed: d_first_installment}` for the Ledger.
- `excludes: [ids]` on keystones (symmetric, validated): the two schools of a detail, plus the cross-detail
  pairs in keystones.md.
- `can_allocate` reason codes, in check order: `unknown, allocated, locked, gate_skill, gate_deed, requires,
  excluded, keystone_limit, no_marks` — the UI maps each to one line of copy ("Needs Mining 3", "Excluded by
  Mole", "Two keystones already").
- `can_undo` → `unknown, not_allocated, grace, dependents`: free take-back within `undo_grace_ticks` (1800 = one
  day) as long as no allocated node would lose its requirements.
- Keystone cap `max_keystones` 2. Rule flags: `rules(st)` / `has_rule(st, x)` (cached with the stat cache).
- Nothing is ever removed by the sim on its own (no "lost a keystone on injury"); traits own the scar layer.

## Why 6 / 5 / 2 and the ring (r2)
- 6 minors are the glue (5–20 %): a mark earned early is never wasted, the entry gate (L3) matters immediately,
  and the spine (m1, m3) is the cheapest road to the shared notable n2. Trimmed from 8 to keep the card at six
  rows with two keystones.
- 5 notables (25–60 %, often two stats or a cost) are the mid-game decisions and each is an identity on its own
  (The Mule, Foreman, Hot Pour, Grease Monkey, Marksman, Cast Iron, Fence…). Two of a school unlock its keystone.
- 2 keystones per detail = two schools (Mule / Digger, Clean / Dirty, Fixer / Artisan, Wall / Killer,
  Doctor / Survivor, Trustee / Smuggler). They exclude each other: a card is a fork, not a ladder.
- 2 bridges per seam: every detail has **six** capstone options (2 own + 4 shared), and the ring makes neighbour
  trades talk (Yard + Infirmary = Walking Wounded *or* Stretcher Bearer; Ledger + Pit = Quota Hawk *or* Pocket
  Vein — the Submit and the Escape answer to the same two details).

## Synergy table (what the board does with what exists)
| build | pieces | result |
|---|---|---|
| Clean refiner | Slow Pour + Cold Hands + Slow Hands | contamination per batch -105 % → his batches *clean* the planet's ledger (the integration clamps the batch at 0, never negative); half throughput; he strikes above 50 % taint |
| Dirty refiner | Hot Pour + Essence Lung + Tinkerer branch | operate +55 %, waste -18 %; cannot be tended, lives on tainted ground, creatures hunt him |
| Mule | Beast of Burden + The Mule + Strong trait | one trip per stack, no armour: the belt-less early-game hauler who must never be in a wave |
| Quartermaster | Reloader + Grease Monkey + Armourer's Pride | gear totals x2, no wear, ammo -45 % (his gun is a club: melee only) |
| Berserker | Short Fuse + Scar Tissue + a miserable block | +50 % damage at mood 0, breaks x2: the Fight-path gamble |
| Night shift | White Nights + Cast Iron + Calm Voice | work +50 % around the clock, breaks -35 % … and x3 at night |
| Trustee block | Trustee + Model Prisoner + Chaplain (another inmate) | zero dues, block despair halved, but the block has an informant it knows about |
| Ghost | Ghost on the Roll + Fence + Pocket Vein | contraband from ore without a refinery, zero suspicion: the Escape engine |

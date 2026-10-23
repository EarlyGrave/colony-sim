# Passives v2 — earned passive abilities ("marks"), revision 2

Status: `[BUILT, flag OFF: passives_v2_enabled]` (code + data on main, not integrated). `data/passives_v2.json` (schema 3), `sim/perks/passive_tree_v2.gd`,
`tests/test_passives_v2.gd` (15 tests), icons `assets/sprites/passive_*.png` (gen_art `# region passives_v2`).
Flag `balance.passives_v2_enabled` = **false** (zero behaviour change, goldens byte-identical). Defs does **not**
load the file; `PassiveTreeV2.load_default()` reads it (integration adds one line to `Defs.load_from`).

r2 (2026-10-21, owner feedback): the board is shared and not skill-bound, so the owner asked for **more and
stronger notables** and **build-defining keystones** in the PoE2 sense (a rule change with a hard trade-off, not
a +%). Result: 36 minor / 30 notable / 24 keystone, every keystone carries rule flags; see keystones.md.

| file | content |
|---|---|
| this README | pillars, rules in one page, point economy summary, how it sits next to perks / branches / traits / gear |
| [board.md](board.md) | structure decision (six "work details" on one board, two schools per detail, two bridges per seam), phone layout, graph rules |
| [earning.md](earning.md) | every mark source with numbers (milestones, deeds, quests, NG+ dossier), budget re-check for 90 nodes, respec economy |
| [keystones.md](keystones.md) | the 24 keystones: PoE source pattern, rule change + drawback each, excludes |
| [integration.md](integration.md) | exact hook lines per stat **and per rule flag** (consumer file:line, new or existing), bus wiring, save/replay, UI, bot, ship checks |
| [table.md](table.md) / [table.json](table.json) | all 90 passives: icon, name, tree, tier, text, numbers, requires, how earned, rule, drawback |

Not here: **traits** (innate / acquired personality, body, history) — the parallel traits v3 lead owns those
(`t_` ids). Passives are only ever *earned*: skill milestones, deeds, quest rewards, the NG+ dossier. No passive
shares a name with a traits v3 trait (r2 renamed Second Skin → Lead Apron, Stoic → Long Memory, Warden's Ear →
Model Prisoner).

## Pitch
RimWorld gives you people; Path of Exile gives you a build. Our inmates get a **work record**: the Warden's ledger
has a page per prisoner and every page fills with *marks* — for skill milestones, for deeds ("still standing after
three waves"), for quest favours. Marks are spent on a small **board of six work details** (Pit, Stacks, Shop, Yard,
Infirmary, Ledger). Each detail is a card of 6 minor nodes, 5 notables and **2 keystones = two schools** (Mule /
Digger, Clean / Dirty, Fixer / Artisan, Wall / Killer, Doctor / Survivor, Trustee / Smuggler); **two bridge
keystones per seam** sit between neighbouring details and need a notable on both sides. A keystone *rewrites a
rule* for that inmate and always costs something (Essence Lung: medicine does nothing, he heals x3 on tainted
ground and the creatures hunt him). A first keystone is 10 marks — a day-25 decision, not an end-game trophy.

Inspiration, reworked: PoE's shared web and keystones (→ one board cut into six phone-sized cards; keystones as
rule flags consumed by our own systems, see keystones.md for the live-checked PoE list), Grim Dawn devotions
(→ bridge keystones that only open when you straddle two trades), Darkest Dungeon camping skills / Battle
Brothers perks (→ flat, readable numbers, drawbacks on keystones only), XCOM class trees (→ a detail is a class
you *earn into*, not one you pick at spawn; two schools per class), Factorio research (→ deeds are the
colony-wide "you did the thing" unlocks, counted from existing records).

## Rules (the short version)
1. **One currency, "marks"**, per inmate. `State.marks_earned - marks_spent`. Sources in [earning.md](earning.md):
   skill milestone L3 → 1, L6 → 2, L10 → 3 (per skill); 16 deeds worth 1–3; quest verbs; NG+ dossier (≤ 4).
2. **Costs**: minor 1, notable 2, keystone 3. Keystones remembered by the dossier cost 0 next run.
3. **Graph**: every node lists `requires_groups` (each group: ≥ n of `any`). Minors chain from the detail's entry
   node down a spine; a detail keystone needs **2 of its school's 3 notables** (n2 is shared by both schools); a
   bridge keystone needs **1 notable in each** of its two details. An entry node has a `gate`: skill level ≥ 3 in
   the detail's skill (any of two for Pit / Yard) or, for the Ledger, the deed *First Installment*.
4. **At most 2 keystones** per inmate (`marks.max_keystones`), and keystones carry `excludes` (the two schools of
   a detail, and pairs whose rules contradict: pacifist vs fights-to-the-death, four ways of not paying in
   essence…). Why 2 and not 1 (decided without owner, review): one keystone is an identity, the second is the
   twist — the build fantasy ("Dead Man Walking who pays his debt in blood") lives in the pair; bridges need
   notables on both sides, so a two-keystone inmate is a 17-mark day-45 investment, not a Tuesday. Why not 3:
   rule flags multiply (no-sleep + no-medicine + never-flees is a rules soup nobody can read on a phone), the
   sheet shows exactly two keystone badges next to the name, and the excludes list would explode.
5. **Undo for free** inside one day of allocating (`undo_grace_ticks` 1800) if nothing depends on the node — a
   phone needs a misclick guard more than a respec screen.
6. **Respec** = forget the whole board: `per_mark` 1 refined essence × marks spent × path multiplier
   (Submit 0.5 / Fight 1.0 / Escape 1.5 — the Warden sells retraining to the obedient), plus 5 block Standing per
   keystone forgotten (the block saw you change sides), plus a 3-day lockout. Marks come back in full.
7. **Effects**: numeric stats are additive and read only via `PassiveTreeV2.mod(state, stat)`; caps (lower
   bounds) in `caps` mirror perks D23 (`waste_mult` / `contamination_per_batch` ≥ -0.4 on the *sum* of perks +
   passives). **Rule flags** (`effects` `rule_<x>`: 1, keystones only) are read via `rules(state)` /
   `has_rule(state, x)`; each rule names its consumer line in `rule_consumers` and [integration.md](integration.md).
   A rule may lift a cap (`rule_uncapped_contamination_per_batch`: Slow Hands).
8. **Deterministic**: no rng anywhere in the module; allocation order is part of the state hash; the state
   serialises with `to_dict/from_dict` (save) and every change is a `Simulation` command (replay).
9. **All in-game text English**, ≤ 70 chars per description (`validate()` enforces it, plus: rule keys have a
   consumer, excludes are symmetric, every keystone has `rule` and `drawback` text).

## How it sits next to what exists
| system | relation |
|---|---|
| Perks (`data/perks.json`, 80, per-skill, 1 pt / 2 levels) | Stay as the *skill* layer (fast, per-skill, actives). Passives are the *career* layer: slower, cross-skill, no actives, and the only place rules change. Stat keys are shared on purpose so both land on the same hook line; if the owner later wants one system, perks' tiers 1–3 become minors and tiers 4–5 notables and the perk tree is retired (reversible). |
| Branches at L5 (`skills.json branches`) | Notables deliberately *extend* branches: Prospector + Vein Reader = ore ×1.5; Gunner + Reloader = long bursts you can feed. Keystone rules are what branches never had. |
| Traits (v2 today, v3 in parallel) | Traits are rolled; passives are earned. Same additive hook style (`traits.mod`); two rule flags reuse trait tags on the same line (`despair_frozen`, `target_weight`). No passive duplicates a trait name; a trait may *gate* nothing here (kept independent so the two leads do not block each other). |
| Gear / affixes / quality | Shop detail feeds quality (`quality_tier`, `craft_quality`) and durability (`gear_wear`, behind `wear_enabled`); Armourer's Pride doubles gear totals, Beast of Burden locks armour slots, Jury Rig caps quality, Signature Work / Essence Smith add tiers. |
| Debt / Standing / suspicion / contraband | Ledger detail: Trustee (zero dues, always the informant), Ghost on the Roll (off the roll, can never pay), Blood Debt (pays in HP), Quota Hawk (pays in ore), Pocket Vein (skims ore into the stash). |
| Contamination / mutation / creatures | Stacks detail: Slow Hands (breaks the cap at half speed), Essence Lung (heals on taint, hunted), Tailings Eater (mining becomes dirty), Essence Smith / Overclock (gear bought with planet health). The pillar lives here. |
| Combat / health | Yard + Infirmary: Dead Man Walking (no downed state), Short Fuse (mood → damage), Walking Wounded (pain ignored), Stretcher Bearer (medic under alarm), Field Surgeon (hospital anywhere), White Nights (never sleeps). |
| NG+ dossier (`meta_state.ng.dossier`) | Carries `{marks ≤ 4, known_for: [keystone ids]}`; known keystones are free next sentence ("the record follows you"), rules included. |
| Quests (`docs/story`) | Quest verb `passive_mark {who, n}` and `passive_deed {who, id}` (integration); story lines can hand out a deed ("Carried a Friend") as a reward. |

## Counts
90 passives: 36 minor, 30 notable, 24 keystone (12 detail = 6 × 2 schools, 12 bridge = 6 seams × 2). 6 details ×
13 nodes + 12 bridges. 16 deeds. 36 rule flags with named consumers. Per-detail focus: Pit (mining/haul/build),
Stacks (refining/contamination), Shop (craft quality/durability/ammo/repair), Yard (combat), Infirmary
(medicine/needs/mood/mutation), Ledger (debt/Standing/suspicion/contraband).

## Open questions for the owner (decided without owner, review)
- Two keystones max with excludes (not one): see rule 4. Cap to 1 if two-rule inmates read as noise on the phone.
- Point budget unchanged (first keystone at 10 marks, keystone + bridge at 17): the board is wider, not deeper.
  First knob if marks pile up: notable cost 3.
- Slow Hands is the only node that breaks the -40 % contamination floor; it pays with half speed and a strike
  rule. Remove the `uncapped` flag if the clean refiner trivialises the pillar in bot runs.
- Ghost on the Roll makes *Paid in Full* impossible for that inmate: intended (the Escape keystone), but it needs
  a line in the Submit-path UI ("not on the roll").
- Respec paid in refined essence like perks (owner wanted "debt/essence/Warden favour": path multiplier covers favour).

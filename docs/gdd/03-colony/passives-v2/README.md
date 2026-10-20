# Passives v2 — earned passive abilities ("marks")

Status: `[DESIGNED]` + code done, not integrated. `data/passives_v2.json`, `sim/perks/passive_tree_v2.gd`,
`tests/test_passives_v2.gd`, icons `assets/sprites/passive_*.png` (gen_art `# region passives_v2`).
Flag `balance.passives_v2_enabled` = **false** (zero behaviour change, goldens byte-identical). Defs does **not**
load the file; `PassiveTreeV2.load_default()` reads it (integration adds one line to `Defs.load_from`).

| file | content |
|---|---|
| this README | pillars, rules in one page, point economy summary, how it sits next to perks / branches / traits / gear |
| [board.md](board.md) | structure decision (six "work details" on one board, not per-skill trees, not a PoE web), phone layout, graph rules |
| [earning.md](earning.md) | every mark source with numbers (milestones, deeds, quests, NG+ dossier), budget model, respec economy |
| [keystones.md](keystones.md) | the 12 keystones with drawbacks and the fantasy of each |
| [integration.md](integration.md) | exact hook lines per stat (consumer file:line), bus wiring, save/replay, UI, bot, ship checks |
| [table.md](table.md) / [table.json](table.json) | all 78 passives: icon, name, tree, tier, text, numbers, requires, how earned |

Not here: **traits** (innate / acquired personality, body, history) — the parallel traits v3 lead owns those
(`t_` ids). Passives are only ever *earned*: skill milestones, deeds, quest rewards, the NG+ dossier.

## Pitch
RimWorld gives you people; Path of Exile gives you a build. Our inmates get a **work record**: the Warden's ledger
has a page per prisoner and every page fills with *marks* — for skill milestones, for deeds ("still standing after
three waves"), for quest favours. Marks are spent on a small **board of six work details** (Pit, Stacks, Shop, Yard,
Infirmary, Ledger). Each detail is a short ladder of 8 minor nodes, 3 notables and 1 keystone; **six bridge
keystones** sit between neighbouring details and need a notable on both sides. Keystones are big and always cost
something (Essence Lung: waste -20 % but the creatures smell you). A full detail is 17 marks — an end-game
specialist, not a Tuesday.

Inspiration, reworked: PoE's shared web (→ one board, but cut into six phone-sized cards and gated by the detail's
skill), Grim Dawn devotions (→ bridge keystones that only open when you straddle two trades), Darkest Dungeon
camping skills / Battle Brothers perks (→ flat, readable numbers, drawbacks on keystones only), XCOM class trees
(→ a detail is a class you *earn into*, not one you pick at spawn), Factorio research (→ deeds are the colony-wide
"you did the thing" unlocks, counted from existing records).

## Rules (the short version)
1. **One currency, "marks"**, per inmate. `State.marks_earned - marks_spent`. Sources in [earning.md](earning.md):
   skill milestone L3 → 1, L6 → 2, L10 → 3 (per skill); 16 deeds worth 1–3; quest verbs; NG+ dossier (≤ 4).
2. **Costs**: minor 1, notable 2, keystone 3. Keystones remembered by the dossier cost 0 next run.
3. **Graph**: every node lists `requires_groups` (each group: ≥ n of `any`). Minors chain from the detail's entry
   node; the detail keystone needs **2 of its 3 notables**; a bridge keystone needs **1 notable in each** of its two
   details. An entry node has a `gate`: skill level ≥ 3 in the detail's skill (any of two for Pit / Yard) or, for the
   Ledger, the deed *First Installment* (you have paid the Warden at least once).
4. **At most 2 keystones** per inmate (`marks.max_keystones`). Mixing a detail keystone with a bridge one is the
   intended "build".
5. **Undo for free** inside one day of allocating (`undo_grace_ticks` 1800) if nothing depends on the node — a
   phone needs a misclick guard more than a respec screen.
6. **Respec** = forget the whole board: `per_mark` 1 refined essence × marks spent × path multiplier
   (Submit 0.5 / Fight 1.0 / Escape 1.5 — the Warden sells retraining to the obedient), plus 5 block Standing per
   keystone forgotten (the block saw you change sides), plus a 3-day lockout. Marks come back in full.
7. **Effects are additive stats** read only via `PassiveTreeV2.mod(state, stat)`; caps (lower bounds) in
   `caps` mirror perks D23 (`waste_mult` / `contamination_per_batch` ≥ -0.4 — the integration applies the cap to
   the *sum* of perks + passives, see integration.md). Every stat has an existing consumer or a one-line hook;
   the list is in `stat_consumers` and in [integration.md](integration.md).
8. **Deterministic**: no rng anywhere in the module; allocation order is part of the state hash; the state
   serialises with `to_dict/from_dict` (save) and every change is a `Simulation` command (replay).
9. **All in-game text English**, ≤ 70 chars per description (`validate()` enforces it).

## How it sits next to what exists
| system | relation |
|---|---|
| Perks (`data/perks.json`, 80, per-skill, 1 pt / 2 levels) | Stay as the *skill* layer (fast, per-skill, actives). Passives are the *career* layer: slower, cross-skill, no actives. Stat keys are shared on purpose so both land on the same hook line; if the owner later wants one system, perks' tiers 1–3 become minors and tiers 4–5 notables and the perk tree is retired (reversible). |
| Branches at L5 (`skills.json branches`) | Notables deliberately *extend* branches: Prospector + Vein Reader = ore ×1.45; Gunner + Reloader = long bursts you can feed. Keystone drawbacks are what branches never had. |
| Traits (v2 today, v3 in parallel) | Traits are rolled; passives are earned. Same additive hook style (`traits.mod`). No passive duplicates a trait name; a trait may *gate* nothing here (kept independent so the two leads do not block each other). |
| Gear / affixes / quality | Shop detail feeds quality (`quality_tier`, `craft_quality`) and durability (`gear_wear`, new hook, lives behind the existing `wear_enabled` switch); Armourer's Pride is the gear keystone. |
| Debt / Standing / suspicion / contraband | Ledger detail: installments, Standing gain, suspicion from covert sales, stash size, sale price. Trustee is the Submit-path keystone; Quota Hawk the production one; Chaplain the block-morale one. |
| Contamination / mutation / creatures | Stacks detail: waste, contamination per batch, mutation risk, threat attraction. The pillar lives here: Essence Lung and Essence Smith trade planet health for output. |
| NG+ dossier (`meta_state.ng.dossier`) | Carries `{marks ≤ 4, known_for: [keystone ids]}`; known keystones are free next sentence ("the record follows you"). |
| Quests (`docs/story`) | Quest verb `passive_mark {who, n}` and `passive_deed {who, id}` (integration); story lines can hand out a deed ("Carried a Friend") as a reward. |

## Counts
78 passives: 48 minor, 18 notable, 12 keystone (6 detail + 6 bridge). 6 details × 12 nodes. 16 deeds.
Per-detail stat focus: Pit (mining/haul/build), Stacks (refining/contamination), Shop (craft quality/durability/
ammo/repair), Yard (combat), Infirmary (medicine/needs/mood/mutation), Ledger (debt/Standing/suspicion/contraband).

## Open questions for the owner (decided without owner, review)
- Point budget: 17 marks per full detail; a 60-day inmate reaches ~12–18 (earning.md model). Too slow → raise
  milestone marks to 1/2/4 or add "per day on the detail" trickle.
- Two keystones max (not one) so bridge keystones are reachable; cap to 1 if builds feel samey.
- Respec paid in refined essence like perks (owner wanted "debt/essence/Warden favour": path multiplier covers favour).
- Ledger gate by deed (not skill) is deliberate: politics is open to anyone who has paid once.

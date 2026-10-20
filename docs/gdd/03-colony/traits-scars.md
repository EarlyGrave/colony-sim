# Traits v2 and acquired scars

Status: `[BUILT]` — `sim/colonists/trait_system.gd` (`mod(c, stat)`, `has_tag`, `grant`), `data/traits.json`
(schema 2), rolled in `generator.gd`. All stats consumed as of F3c/F4e (see table). Design source:
[docs/design/progression_traits.md §3](../../design/progression_traits.md).

## Rules
- Innate physical/character features; affect peace-time (work, food, mood) and stress-time (despair, breaks,
  flee). **Never purely negative**: each has a niche (owner).
- Weighted draw without replacement: common 30 / uncommon 12 / rare 5; `max_traits` 2; 25 % no traits;
  `excludes` pairs never co-occur (500-inmate test); `block_only` honoured (block assigned first).
- Effects are additive via `sim.traits.mod`; `c.bio.work_speed` stays cached for the view. Alias `lazy` ->
  `slow_burner`. Deterministic: fixed draw count per colonist.

## The 20 innate traits (name — niche)
Strong (mining +2, carry +25 %; excl. Frail) · Frail (hunger -20 %, work -8 %, xp craft/med +15 %) ·
Handy (construction +2, crafting +2) · Careful (medicine +2, breakage -30 %, work -5 %; excl. Hasty) ·
Hasty (work +10 %, hit -8 %, quality -1) · Slow Burner (work -10 %, mood +6, despair x0.8) · Green Thumb
(plants +3, xp plants +20 %) · Iron Stomach (raw-food thoughts ignored, hunger +10 %; excl. Delicate) ·
Delicate (ate_raw x2, medicine +1, xp all +10 %) · Night Owl / Early Bird (work +15 % at night/day,
-10 % the other; mutually exclusive) · Cold Blood (never flees, breaks -50 %, xp med -20 %; excl. Jittery)
· Jittery (flees early, move +15 %, xp shooting +30 % on the range) · Done Time (lifer only: despair x0.7,
xp all -10 %; excl. Quick Study) · Quick Study (xp all +25 %, mood -3) · Essence Nose (refining +10 %, no
taint thoughts, mutation risk +20 %; pillar tie-in) · Thick Hide (flat armour +1, hunger +10 %) ·
Loud Mouth (block Standing gain +50 %, own breaks +20 %) · Ledger Eye (clerk only: installment -5 %,
work -5 %) · Scrapper (melee +2, unarmed hit +10 %).

## Acquired traits ("scars") — decided without owner, review; max 1 per inmate; `data/traits.json acquire`
| trait | trigger | effect |
|---|---|---|
| Hardened | downed then rescued | injured thought x0.5, flee threshold -0.3 |
| Resigned | despair >= 80 for 5 days | despair stops growing, work -15 %, mood +4 |
| Settled | 30 days without a break | mood +5; leaves if the colonist breaks |
Quest verb `trait {who,id}` can grant one (r4 lines). Dossier carries innate + acquired ids into NG+
(`start_opts.gd` re-applies them).

## Stats consumed (one hook each)
work_speed (jobs), carry (haul), hunger (needs), mood_base / thought_<id> (mood), break_chance (mood),
despair_mult / installment_pct (debt), flee_threshold (jobs flee), hit / unarmed_hit / armor_flat (combat
resum), xp_mult_<skill> (award), standing_gain (blocks), mutation_risk (mutation), night/day work (needs
clock), machine_breakage (buildings), refining_speed (operate), quality_tier (quality), move_speed (mover).

## Open (owner)
Owner note: "emergence over time is an open question (no RimWorld children)". Scars are the chosen answer;
confirm (README question 13). Role affinity (`roles.json affinity trait_weight`) suggests squad roles.

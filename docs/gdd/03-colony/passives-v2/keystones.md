# The 12 keystones

Rule: a keystone *changes how the inmate plays* and *always costs something visible*. Cost 3 marks (0 if the NG+
dossier remembers it). Max 2 per inmate. Detail keystones need 2 of the detail's 3 notables; bridge keystones
need 1 notable in each neighbouring detail. Exact numbers in table.md; consumers in integration.md.

## Detail keystones
| id | name | fantasy | upside | drawback |
|---|---|---|---|---|
| `p_pit_lifers_back` | Lifer's Back | twenty years of sacks | carry ×2, mining +25 % | hunger +25 %, move -15 % — the mule eats and plods |
| `p_stacks_essence_lung` | Essence Lung | breathes the fumes like air | waste -20 %, operates +20 % | mutation risk +50 %, threat_attract +30 % — creatures smell essence on them; the pillar in one node |
| `p_shop_signature_work` | Signature Work | every piece is signed | +1 quality tier, better rolls, own gear wear -50 % | crafts 30 % slower, uses 15 % more input — quality over quota |
| `p_yard_dead_man_walking` | Dead Man Walking | nothing left to lose | never flees, damage -20 %, hit +10 % | mood -8, heals 30 % slower — the colony's shield wall is also its saddest inmate |
| `p_infirmary_field_surgeon` | Field Surgeon | hands that fix, not fight | tend +40 %, patients heal +30 % | hunger +20 %, combat XP halved — they will never be a fighter |
| `p_ledger_trustee` | Trustee | the Warden's favourite | installments -20 %, Standing +50 %, suspicion -50 % | despair +30 %, work -10 % — owes everything to the man with the ledger; Submit-path flavour, works on any path |

## Bridge keystones (ring order)
| id | between | name | upside | drawback |
|---|---|---|---|---|
| `p_key_clean_hands` | Pit + Stacks | Clean Hands Doctrine | contamination per batch -20 %, ore +15 % | operates 25 % slower — "slow is safe", the Fight-path refiner |
| `p_key_essence_smith` | Stacks + Shop | Essence Smith | craft quality +1.5 rolls, input -20 % | contamination +20 % when *they* run a batch — gear bought with planet health |
| `p_key_armourers_pride` | Shop + Yard | Armourer's Pride | gear wear -50 %, armour +2, ammo -25 % | builds 20 % slower — the quartermaster is not a builder |
| `p_key_walking_wounded` | Yard + Infirmary | Walking Wounded | damage -10 %, own heal +50 %, injury thoughts halved | tends others 20 % worse — patches themself, not you |
| `p_key_chaplain` | Infirmary + Ledger | Chaplain | despair -25 %, breaks -25 %, mood +3 | learns 15 % slower (xp_mult_all) — spends the shift talking people down |
| `p_key_quota_hawk` | Ledger + Pit | Quota Hawk | ore +20 %, installments -10 % | threat_attract +15 %, mood -4 — works the vein loud and hates it |

## Design notes
- Drawbacks are on stats the player can *see* on the sheet (hunger, mood, move, XP, Standing) so the trade is
  legible on a phone without tooltips. No hidden "chance of X" drawbacks.
- Essence Lung, Essence Smith and Quota Hawk are the three ways the board can hurt the planet; Clean Hands,
  Slow Pour and Cold Hands are the three ways it can help. The cap (-40 %) keeps a clean refiner from making
  contamination irrelevant: the pillar stays.
- Dead Man Walking's `flee_threshold -1.0` is the same hook Cold Blood (trait) uses (`job_system.gd:35`): an
  inmate can be both, nothing stacks past "never flees".
- Chaplain's effect is per inmate, not an aura; an aura would need a new consumer loop (rejected for phone perf).
  If the owner wants block-wide morale, the hook is `block_system.despair_mult(c)`: read the block's chaplain once
  per day and cache the multiplier.
- Trustee is intentionally strong on Submit and awkward on Escape (suspicion -50 % helps covert sales, but despair
  +30 % feeds riots): a keystone the path argues about.
- NG+: "known for" keystones are free next run, but the drawbacks are of course still there — the veteran arrives
  as the character the player built.

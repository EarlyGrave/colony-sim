# The 24 keystones (r2: build-defining rule changes)

Owner feedback 2026-10-21: "keystones must be build-defining — they flip the gameplay for that colonist, like
PoE2's Chaos Inoculation or Eldritch Battery." Checked live (PoE / PoE2 keystone lists, 2026-10-21): every PoE
keystone is a **rule rewrite with a hard trade-off**, never a +%: Chaos Inoculation (immune to chaos, life = 1),
Eldritch Battery (energy shield protects mana instead of life), Blood Magic (skills cost life, no mana),
Giant's Blood (two-hander in one hand, triple attribute requirements), Avatar of Fire (75 % of damage becomes
fire, no non-fire damage), Unwavering Stance (double stun threshold, cannot dodge roll), Mind over Matter (damage
hits mana first, half mana recovery), Resolute Technique (accuracy doubled, never crits), Pain Attunement (more
crit damage on low life, less on full), Iron Reflexes (evasion becomes armour), Oasis (no charms, flasks
recover more), Vaal Pact (leech instant / doubled, no regen).

Our translation: a keystone sets one or more **rule flags** (`effects` `rule_<x>`: 1, read by the consumer
system through `PassiveTreeV2.has_rule(st, "<x>")`) plus a few big numbers, and always a drawback you can see on
the sheet. Reworked for the prison planet: debt, essence, contamination, the Warden, the block.

Rules: cost 3 marks (0 if the NG+ dossier remembers it). **Max 2 per inmate** (why: README). The two keystones of
one detail are its two *schools* and exclude each other; cross-detail `excludes` stop nonsense pairs (a pacifist
cannot also fight to the death). Detail keystones need 2 of the school's 3 notables; bridge keystones need 1
notable in each neighbouring detail. Numbers in table.md, hook lines in integration.md.

## Detail keystones (two schools per detail)
| id | detail / school | rule change | drawback |
|---|---|---|---|
| `p_pit_beast_of_burden` | Pit / Mule | **No carry cap**: a haul takes the whole stack | Cannot wear armour (non-weapon slots locked, worn pieces drop on allocate); move -20 % |
| `p_pit_mole` | Pit / Digger | Mining x2 speed, ore +50 % | Every non-mining job at 40 % speed (`rule_mining_only`) |
| `p_stacks_slow_hands` | Stacks / Clean | His batches contaminate -60 % and **ignore the -40 % floor** | Operates at half speed; downs tools on refineries while planet contamination > 50 % |
| `p_stacks_essence_lung` | Stacks / Dirty | **Medicine does nothing**; wounds heal x3 on tainted ground, x0 elsewhere; immune to taint sickness; operates +25 % | Creatures weight him x2 as a target (`target_weight`) |
| `p_shop_jury_rig` | Shop / Fixer | Repairs x3; machines he operates never break | Everything he crafts is Common; buildings he raises -30 % HP |
| `p_shop_signature_work` | Shop / Artisan | Crafted gear +2 quality tiers, high rolls | Half craft speed; takes no job but crafting (`rule_craft_only`) |
| `p_yard_dead_man_walking` | Yard / Wall | Never flees; **downed state skipped** (fights until dead); damage taken -30 %, hit +15 % | Dies where others would be downed; mood -10; heals 50 % slower |
| `p_yard_short_fuse` | Yard / Killer | **Mood is ammunition**: damage x (1 + 1 % per mood point under 50), x0.75 above 50 | Breaks roll at twice the chance |
| `p_infirmary_field_surgeon` | Infirmary / Doctor | His patients get the bed heal rate wherever they lie; tend +50 %; no infections from his tending | Cannot be drafted (militia skips him); hunger +30 % |
| `p_infirmary_white_nights` | Infirmary / Survivor | **Never sleeps** (rest need removed); all work +50 % | At night: thought -15 and the daily break roll runs at x3 |
| `p_ledger_trustee` | Ledger / Trustee | **Installments are zero** (interest still grows); suspicion -50 % | He is the block informant whenever alive; earns no Standing; despair +50 % |
| `p_ledger_ghost_on_the_roll` | Ledger / Smuggler | **Off the roll**: no installments, no interest, sales add no suspicion, shakedowns skip his stash; sales +25 % | Can never pay the debt off (no Paid in Full, no Submit payoff); earns no Standing |

## Bridge keystones (two per seam, ring order)
| id | between | rule change | drawback |
|---|---|---|---|
| `p_key_clean_hands` | Pit + Stacks | Ore +50 %; his mining draws no creatures at all | **Never takes a refinery job** |
| `p_key_tailings_eater` | Pit + Stacks | **Tainted rock yields x2 ore**; immune to taint sickness | Every 50 ore he mines adds 1 unit of contamination (mining is no longer safe for him) |
| `p_key_essence_smith` | Stacks + Shop | Crafts with raw essence: +2 tiers, input -20 % | Each craft eats 1 essence ore and adds a quarter batch of contamination |
| `p_key_overclock` | Stacks + Shop | Machines run x2 under him | Machine wear x4; a burn injury every 10th batch |
| `p_key_armourers_pride` | Shop + Yard | **Non-weapon gear totals x2**; gear never wears | Cannot equip ranged weapons; no shooting XP |
| `p_key_full_auto` | Shop + Yard | **Ammo use 0**; attacks +25 % faster | Draws creatures x2; no melee XP |
| `p_key_walking_wounded` | Yard + Infirmary | **Pain ignored**: injuries never throttle work, no injured thought, never retreats at low HP | Bleeds x2; never flees |
| `p_key_stretcher_bearer` | Yard + Infirmary | On alarm he **rescues and tends instead of hiding**; carried patients stop bleeding; move +20 % | Never attacks; cannot be drafted |
| `p_key_chaplain` | Infirmary + Ledger | **Block aura**: his block's despair grows at half rate while he lives; his own never grows | No XP in any skill; works 30 % slower |
| `p_key_blood_debt` | Infirmary + Ledger | **Pays dues in blood**: on due day the installment is booked paid and a 20 % max-HP "letting" wound is applied; no essence | Heals 30 % slower; downed on due day = installment missed |
| `p_key_quota_hawk` | Ledger + Pit | **Pays in ore**: every 10 ore he mines books 1 installment credit, no essence | Never hauls or delivers; mood -6; draws creatures +30 % |
| `p_key_pocket_vein` | Ledger + Pit | **Skims ore**: 10 % of what he mines becomes contraband in his stash; stash +5 | Shakedowns empty his stash first; draws creatures +30 % |

## Excludes (data `excludes`, symmetric; reason code `excluded`)
- Each detail's two schools: Beast of Burden x Mole, Slow Hands x Essence Lung, Jury Rig x Signature Work,
  Dead Man Walking x Short Fuse, Field Surgeon x White Nights, Trustee x Ghost on the Roll.
- Downed / pain rewrites: Dead Man Walking x Walking Wounded.
- Pacifist vs fighter: Stretcher Bearer x Dead Man Walking, Short Fuse, Full Auto, Armourer's Pride; Full Auto x
  Armourer's Pride (ranged vs melee only).
- Job filters: Mole x Signature Work, Mole x Quota Hawk.
- Four ways of not paying in essence: Blood Debt, Quota Hawk, Trustee, Ghost on the Roll pairwise.
- Clean Hands (never refines) x Essence Lung, Slow Hands, Overclock, Essence Smith; Essence Smith x Jury Rig;
  Essence Lung (no medicine) x Field Surgeon; White Nights x Chaplain (work +50 % vs -30 %).

## Design notes
- Every keystone touches the pillar or the path: Tailings Eater / Essence Smith / Overclock / Essence Lung make
  the planet pay for output; Slow Hands / Clean Hands are the "slow is safe" builds (Slow Hands is the one node
  that breaks the -40 % cap, at half throughput — the pillar stays because he refuses to work a dirty planet).
- Submit builds: Trustee (zero dues, hated), Quota Hawk (pays in ore). Escape builds: Ghost on the Roll (can never
  pay), Pocket Vein (skims). Fight builds: Dead Man Walking, Short Fuse, Full Auto, Armourer's Pride.
- Drawbacks are legible on the phone sheet (locked slots, "never flees", mood, hunger, XP) — no hidden chances
  except Short Fuse's x2 break roll, which the mood bar already explains.
- Chaplain is the one aura; it is read once per day in `block_system.despair_mult` (cached), not per tick.
- `Dead Man Walking` and `Walking Wounded` both set `flee_threshold -1.0`: same hook as Cold Blood (trait); nothing
  stacks past "never flees".
- NG+: "known for" keystones are free next run; the rules (and drawbacks) come with the veteran.

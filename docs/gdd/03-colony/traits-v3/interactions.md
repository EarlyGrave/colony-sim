# Traits v3 — needs, bonds, auras, synergies

## 1. Trait needs (data `needs`, `daily_needs(c, ctx)`)
One daily call per inmate; `ctx` is a dictionary of booleans the consumer fills from existing state.
| trait | want (ctx key) | filled from | days | thought (add to `data/mood.json`) | suggested value |
|---|---|---|---|---|---|
| Tunnel Rat | `mined_today` | JobSystem: had a mine job today | 2 | `no_tunnel` "Too much sky." | -4, 1 day |
| Curious | `research_active` | ResearchSystem: a tech in progress | 3 | `nothing_new` "Same bolts, same days." | -3, 1 day |
| Dreamer | `letter_today` | Storyteller: any letter event today | 5 | `no_letter` "Nothing in the post. Again." | -3, 1 day |
| Creature of Habit | `same_job` | JobSystem: same job type as yesterday | 1 | `routine_broken` "They moved my shift." | -5, 1 day |
| Gallows Humor | `block_mate_alive` | BlockSystem: ≥ 1 living block mate | 1 | `no_audience` "Nobody left to laugh." | -4, 1 day |
| Hums | `near_essence` | ItemSystem: refined essence within 6 cells | 2 | `hum_fades` "The hum is going quiet." | -6, 1 day |
The thought repeats daily while unmet (mood.json durations handle stacking). Routine Broken is the only
cheap "stress" that the player controls directly with priorities — it teaches the trait system in minute 5.

## 2. Thought multipliers (`thought_mult(c, id, value)`)
`thought_<id>` scales one thought (-1.0 = ignored, +1.0 = doubled); `thought_neg` / `thought_pos` scale by
sign (Stoic 0.7/0.7, Hollow 0/0). Replaces v2's per-thought hook in `mood_system.gd:40` with one call.

## 3. Auras (`aura(c, stat, mates)`) — inmates affect inmates
| stat | holders | who feels it | consumer |
|---|---|---|---|
| `aura_mood` | Gallows Humor +2, Cult +1, Wrongful +1, Morbid -1, Second Skin -1, Outcast -1, Hollow -2, Waste Kin -2, Warden's Ear -2 | living block mates | MoodSystem base |
| `aura_break` | Peacemaker -0.2, Block Boss -0.1, Sedition +0.1, Agitator +0.15 | block mates' break roll | MoodSystem |
| `aura_xp` | Mentor +0.1, Rival +0.05 | mates on the same job type (within 4 cells) | ProgressionSystem |
Design intent: a block of mutants is quiet and sad; a block with one joker and one peacemaker holds.
Hollow in a block of fresh fish is a horror beat without a script.

## 4. Path leaning (`leaning(c)` → {submit, fight, escape})
Adds per-inmate votes to the block leaning (`blocks.json leaning`): Compliant/Debt submit, Defiant/Sedition
(2)/Cult (2)/Desertion fight, Fraud/Smuggling/Mutiny/Dreamer/Runner/Wrongful (2) escape. The three endings
become readable in the roster before R5: "this colony wants to run".

## 5. Targeting (`target_weight_mult`)
Creatures prefer the glow: Glowtouched +20 %, Second Skin +30 %, Hulking +20 %, Desertion +50 % (Metropolis
bounty; drones only — the consumer checks the enemy faction), Sealed +10 %. They avoid their own kind:
Waste Kin -40 %, Hollow -50 %, Echo -30 %, Warden's Ear -20 %, Marked -10 %. This is the "mutation as
armour" niche: a Hollow at the refinery is the safest operator on the map and the saddest.

## 6. Synergy recipes (emergent, no code)
- **The quiet refinery**: Charge: Essence Theft + Methodical → +15 % speed, +2 quality tiers, 30 % more
  illness; after 3 illnesses Second Skin: armour, and the block gets `aura_mood -1`. Pillar in one inmate.
- **The informant trap**: Compliant (+3 informant weight) in a block with Reported (-5) and Quiet One (-10):
  the pick is obvious to the player before the Warden makes it.
- **Riot engine**: Agitator + Charge: Mutiny + Volatile in one block: `riot_spread` +100 %, breaks +55 %.
  Counter: one Peacemaker (-50 % spread, -20 % break aura) or a Block Boss.
- **Scout**: Paranoid + Sharp Ears: +3 spot range, +90 warning ticks, flees early — the perfect patrol.
- **Bulwark**: Hulking + Dead Nerves + Second Skin: armour 2, never flees, carries the wounded; -25 hp.
- **Lifer's calm**: Cell Rot → Old Timer + Stoic + Settled: despair -30 %, breaks -55 %, learns -25 %.
- **Ledger team**: Charge: Fraud + Charge: Smuggling in one block (different inmates): sales +10 % price,
  find +50 %, suspicion per sale net 0.
- **Cellmate risk**: two Cellmates in the same squad: flee -10 %, mood +3 each; one dies → the other loses
  the trait, `thought_colonist_died x2`, counter `lost_t_cellmate` for a quest ("Bunk 4 is empty").
- **Anti-synergy**: Greedy + Docked: despair +40 %; Reckless + Bleeder: injury severity +50 %; Curious +
  Reckless on machines: breakage +40 % (give them the mine).

## 7. Rarity of the fun
Legendary traits never roll at birth: Hollow (6 illnesses) and Echo (mimic + Glowtouched) are earned by
the player's own refining pace, the pillar's price made visible on one face.

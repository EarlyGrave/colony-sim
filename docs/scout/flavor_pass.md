# Scout: "Make it alive / make it funny" flavor pass

Verification: live web check done only for Darkest Dungeon / Bastion narration (narrator reacts to play, devs cut
hundreds of lines and kept thousands: techraptor.net, 80.lv; Hades not confirmed live). Everything else [memory].
Existing voice: tutorial.json (Warden forms, "The Warden counts it twice"), names.json (24 nicknames, 8 backstories),
events.json (`text` with `{target}`), enemies crawler/brute/spitter/burrower, bus signals wave_started, wave_repelled,
colonist_downed, colonist_died, research_completed.

Principles: (1) one text bank `data/flavor.json`, keyed by trigger id, each key = list of lines; picker uses `sim.rng`
(determinism) and a "last N used" ring to avoid repeats. (2) Flavor never changes balance. (3) Dry, bureaucratic, short
(<= 70 chars). (4) Sim emits facts via bus; view formats text. Cost S = JSON + 1 view hook, M = new small sim counter.

## Ideas (1-14)
1. **Kill feed with templated puns** [Prison Architect/DF combat log, memory]. Corner ticker (3 lines, fade 6 s),
   template `{who} {verb} {victim} {tail}` picked by creature + death cause. Fields: `feed.<enemy>.<cause>[]`,
   causes: turret, melee, burn, acid, collapse, bleed_out, rubble, starvation.
   - "Crawler #14 filed for retirement. Turret approved it."
   - "Brute removed from the wave. Paperwork pending."
   - "Spitter dissolved in its own opinion." (acid)
   - "Burrower went down. So did the property value." (collapse)
   - "Vera bled out. Cause: workplace." Cost S.
2. **Warden PA announcements** [Papers Please, Paranoia, memory]. Overhead banner + tone, on bus signals. Fields:
   `pa.wave_started[]`, `pa.wave_repelled[]`, `pa.audit[]`, `pa.crisis[]`, `pa.research_done[]`, `pa.colonist_downed[]`.
   - Wave: "Attention inmates: unscheduled visitors. Please remain productive."
   - Audit: "Audit in progress. Smiling is not required, but noted."
   - Crisis: "Taint exceeds comfort. Comfort has been revised."
   - Research: "Innovation granted. Your gratitude is mandatory."
   - Downed: "Inmate down. Please do not step on the paperwork." Cost S.
3. **Inmate barks** [Darkest Dungeon narrator/Hades reactivity, memory]. Speech bubble 2 s above colonist, cooldown 90 s,
   by state: working, fleeing, idle, hungry, low_mood, refining, wave_won. Fields: `barks.<state>[]`, optional
   `trait` filter.
   - Fleeing: "Not in the contract!" / "I have a pod to hide in, and a will to use it."
   - Refining: "It glows. Is it supposed to glow?"
   - Hungry: "The ration was a rumour."
   - Wave won: "Put that on my record. Slowly." Cost S.
4. **Nickname engine** [RimWorld nicknames, memory]. Earn a second nickname from stats: most kills, most downs, most
   hauling, longest refine. Fields: `nicknames.<stat>[]`, threshold in balance.json. Counters per colonist (M).
   - Kills: "Vera 'Paperwork' Kline" ; Downs: "Fox 'Rug' Hale" ; Haul: "Miron 'Donkey'" ; Refine: "Wick 'Glow'".
5. **Record quirks** [Prison Architect prisoner bios + RimWorld traits, memory]. 1 harmless quirk per inmate with a tiny
   bark/flavor effect only (or +-1 mood). Fields: `quirks[]{id,text,bark_bias}`.
   - "Alphabetises the ore." - "Refuses to name the turrets (names them anyway)."
   - "Believes the planet is listening." - "Salutes the pod. Daily." Cost S.
6. **Procedural rap sheets** [PA bios, Paranoia secret societies, memory]. Card in inmate panel:
   `Crime + Sentence + Complaint + Last words`. Compose from lists; seeded by colonist id. Extends names.json
   backstories. Fields: `rapsheet.crime[]`, `.sentence[]`, `.complaint[]`, `.model_trait[]`.
   - "Crime: Embezzled 40 tonnes of air. Sentence: 6 years, 4 remaining, 2 rumoured."
   - "Crime: Unlicensed optimism. Complaint: the pillow."
   - "Crime: Arson (self-defence, lighter). Sentence: until further notice." Cost S.
7. **Commendations** [Factorio achievements, Steam style, memory]. Dry toast + badge, saved in meta; triggers from
   bus counters (data/milestones.json already exists - extend). Fields: `commendations[]{id,title,text,when}`.
   - "Participation Ribbon" (survive wave 1): "You were present. The Warden noted it."
   - "Clean Hands" (day 5 under 10% taint): "Suspiciously tidy."
   - "Mass Disappointment" (lose 3 inmates in a wave): "Management is neither angry nor surprised."
   - "Debt Enthusiast" (essence debt 3 contracts): "You borrow like you mean it." Cost S/M.
8. **Loading-screen / HUD tips** [Factorio tips, Frostpunk laws, memory]. Rotating one-liners on game over and pause.
   Fields: `tips[]`, `gameover.cause.<x>[]`.
   - "Mining is safe. Refining is a lifestyle choice."
   - "Creatures follow noise. Build a cheaper noise."
   - Game over (pod lost): "Your pod has been reclassified as debris." Cost S.
9. **Wave names / audit memos** [DF megabeasts, Darkest Dungeon, memory]. Waves get procedural titles from dominant
   creature + contamination. Fields: `wave_titles.prefix[]/.noun[]`, e.g. "The Spitter Inspection", "Brute Quarterly".
   - "Notice: Q3 Teeth Review." - "Surprise Tenancy Dispute." Shown in the wave warning. Cost S.
10. **Event letters with Warden stamp** [RimWorld letters, memory]. Extra `{flavor}` line appended to events.json text
    from `event_flavor.<event_id>[]`. Lightning: "Weather has been reclassified as a fault of management." Fever:
    "Sick leave is a privilege, and this is a loan." Cave-in: "The rock has filed a counter-claim." Cost S.
11. **Essence debt collector voice** [Papers Please, Frostpunk, memory]. Debt/contract UI messages in lender tone. Fields:
    `debt.<state>[]`. "Interest accrued. So did regret." "Payment received. Smugness not included."
    "Sanctions applied with regret (not ours)." Cost S.
12. **Epitaph on death** [DF slab/engraving, Darkest Dungeon, memory]. On colonist_died, one line saved in a log tab
    "Memorial wall". Fields: `epitaph.cause.<c>[]`. "Wick. Dug well. Died poorly." "Berry: owed 3 days. Forgiven." Cost S.
13. **Creature spawn growls / ecology gossip** [Bastion reactivity, memory]. Tiny warning tag per origin
    ("Something is humming in the north. Not music."). Fields: `omen.<direction|type>[]`. Cost S.
14. **Quiet-day narrator** [Hades/Bastion silence-breaker, memory]. If nothing happens for 1 game day, one dry aside:
    "Nothing happened. The Warden is uneasy." Fields: `idle_quips[]`, cooldown. Cost S.

## Visual juice (pseudo-3D pixel view, cheap) - ideas V1-V4
V1. **Death burst** (shooter feathers analogue): 8-12 sprite particles, colour from enemies.json `color`, 0.4 s, gravity
    arc; brute = 2x count + screen shake 2 px. Field: `fx.death.<enemy>{count,color,shake}`. Extends `effects_3d.gd`. S
V2. **Slime splat decals**: spitter/crawler deaths and acid hits leave a tinted flat quad on the cell, fades 20 s; pooled
    max 40. Tied to taint: splat colour sickly green as contamination rises. S
V3. **Contamination drip**: refinery emits sludge drops landing as small puddles; puddle count mirrors waste output
    (readable "this is dirty" cue, no UI). S
V4. **Number puns floating**: damage text with rare kinds ("OOF" on colonist hit, "AUDITED" on structure hit); 5% chance.
    Also hit-stop 2 frames on brute kill. S

## Plan
Phase A (S): flavor.json + FlavorPicker (sim RefCounted, rng ring), kill feed, PA banner, barks, tips.
Phase B (M): counters for nicknames/commendations, rap sheet, memorial wall.
Phase C (S): V1-V4. Tests: picker determinism, no repeat in last N, every referenced key exists in JSON,
placeholders `{who}` resolved; strings <= 70 chars. Keep tone: mock bureaucracy and the player's greed, never real
groups; no slurs, no gore beyond pixel puffs.

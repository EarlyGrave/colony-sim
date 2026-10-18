# Scout: endgame / long-term production goal (days 15-40)
Problem: bots never reach audit tier 3 (120 plate + 40 parts + 30 copper ingot), so power/nuclear/T3
content is unused and mid/late game has no goal. Existing hooks: milestones.json (audit tiers),
debt.json (refined_essence debt, escape/leave_reward), Parole Reviews, contracts, expedition, power tiers.

## Sources
- Satisfactory (verified live, wiki.gg): Space Elevator = 5 phases of Project Assembly parts
  (50 Smart Plating -> 1000+1000+100 -> ... -> Nuclear Pasta/Warp Drive); each phase unlocks 1-2 tech tiers,
  parts of ONE chain deepen each phase. Idea: goal = staged delivery that also gates content.
- Factorio (verified live, wiki): rocket silo = win; 100 rocket parts, each 10 LDS + 10 fuel + 10 control
  units; satellite payload returns science. Idea: one expensive multi-input build, then a payload choice.
- Dyson Sphere Program (verified live, dsp-wiki): rockets = permanent structure points, sails = temporary
  swarm (5400 s lifespan) that must keep being fed; each point yields power. Idea: permanent vs decaying output.
- Mindustry (partly verified, forum/Steam): launch pad ships items between sectors; core items launched on
  sector win. Idea: "launch" converts stockpile into progress elsewhere.
- RimWorld ship ending, Oxygen Not Included rocketry: from memory, NOT re-verified (ship parts + long
  defend-the-launch window; ONI rockets fetch resources via range/fuel/oxidizer).

## 1. Sentence Commutation Petition (staged, Satisfactory-style) - cost M  [recommended core]
Four "Petition Phases" at the warden terminal, after audit tier 2. Each needs a different chain, each
phase unlocks content and cuts debt: P1 plates+parts (reuse tier-3 bundle but split smaller: 60 plate/20 parts),
P2 +steel/ingot_copper, P3 needs power-chain item (battery/fuel cell; forces coal/nitrogen power),
P4 needs refined essence (debt payoff). Data: new `tiers`-like block in milestones.json "petitions".
Uses: terminal UI, ledger, power nets. Pacing: P1 ~d12, P4 ~d35 on standard; presets scale amounts.
Fixes the tier-3 wall: tier 3 is split so bots get partial credit and visible progress.

## 2. Release Shuttle (Factorio silo twist) - cost L
Final project: build "Release Gantry" (4x4, needs T3 + 20 power); feed it 100 "release parts"
(each = 1 plate + 1 refined_essence + 1 circuit-like part) over time; launch triggers a 2-day
"countdown" in which a huge pollution-driven siege hits the gantry (defend it, RimWorld ship style).
Win = colony ends (legacy points x2, leave_legacy_points). Refining is MANDATORY (essence) so the
pillar bites: the escape is paid with the same pollution that wakes the planet. Uses: threats, debt, meta.

## 3. Sail Swarm (DSP twist: decaying output) - cost M
"Penance beacons": a machine launches temporary beacons (cost: plate + essence) that reduce debt by X%
per day while alive; they decay after ~3 days and must be refilled. Rockets-equivalent permanent
"Pylons" reduce decay. Gives a use for surplus power/belts and an endless sink (no hard win).
Uses: power draw, splitters (feeding), debt.json interest. Cost S-M.

## 4. Sector Dispatch (Mindustry launch pad twist) - cost M
Launch Pad ships bulk goods on an expedition slot to an "outer cell block"; return is not items but
a permanent colony modifier (e.g. -10% wave strength, +1 colonist, new recipe). Expedition bot already
plays Frontier Quota on 3/5 seeds; extend with "dispatch" contract tiers needing 100+ item bundles.
Uses: expedition.json, contracts.json. Cost S.

## 5. Chain Gang Review (ONI rocketry: range/fuel budget) - cost S
Late Parole Review 4 and 5: debt <5%, plus "range score" = power surplus * clean pollution.
Reward = lighter audits, cosmetic rank. Cheap goal for bots: just thresholds in existing Reviews code.

## Recommendation
Do #1 first (data-only mostly, fixes tier-3 wall, reuses terminal), then #4 (S) and #5 (S);
#2 as the true win condition once #1 is stable; #3 optional endless sink. Bot numbers required
before merge: share of seeds reaching P1..P4 by d20/d30; target P1 5/5, P3 3/5, P4 1/5.

# Contraband, covert trade, suspicion

All in `sim/society/contraband.gd`, `data/contraband.json`; commands `squad_shakedown`, `covert_sale`.

## Skim `[BUILT, flag OFF: contraband.json enabled]`
Inmates with despair >= 25 (or a missed installment) skim 1 refined/day each into a hidden stash, capped at
3 % of refined output. Stash >= 4 -> black-market event (relief 1 installment unit within the 2 % debt cap,
wave bump +15 %); `squad_shakedown` recovers it (despair +25, suspicion +10). Runs when the data flag is
on **or** quest flag `contraband_on` is set: quest S4a "Unaccounted essence" (missed installment, d20+) sets
it — the Warden turning it on is the joke (the skim is pre-booked). Decision log: ships OFF until a bot pass
shows it is fun; forced-despair scenario (`tools/contraband_scenario.gd`) was inconclusive. Owner question 15.

## Covert sales (Escape economy) `[BUILT]` (N2, F4a)
- `covert_sale(n)`: needs `path_escape`; sells n refined to the Ferry: +`escape_credit` 1:1 toward the
  bandit fee, +suspicion 2 per unit (x2 while the Informant lives).
- **Suspicion** 0-95 (cap), decays 4/day, -10 per player shakedown, +25 from the P3 "Informant Report"
  waiver, +0.5 defiance per sale on the metro track. >= 60: Warden "friendly inspection" (audit parts x1.3
  for 5 d, 5 refined confiscated, cooldown 3 d); >= 90: raid (10 confiscated). Cond `suspicion_over`.
- Escape bot (`path=3 sell_every=6`, 90 d): suspicion peak <= 84 on 10/10; bandit fee + extraction won 4/10.
- Legacy: 25 per extracted colonist + 0.5 per credit (cap 40) (`contraband.json legacy`).
Design difference: economy_endgame.md put credits/suspicion into `ContractSystem` and `contracts.json buyers`;
built inside the contraband module instead (one buyer, the Ferry). Multiple buyers `[IDEA]`.

## Story hooks (society.md, round4)
S4b "Stash Inventory" (stash > 6): shakedown / let it ride (first black market -> `clue_buyer`, "They asked
for the calm stuff.") / turn it in (`warden_favor`, grace +1 d, skimmers' block -15). r4 "Quiet Freight"
(Escape midgame): sell a dead inmate's ID, friendly inspection, the courier's cage (a mimic), drone tail.

## Where it still bites nothing
With the data flag off and S4a needing a missed installment after d20, most bot runs never see contraband
(the bot pays first). Pillar check if it goes on: aggregate alive over 10 seeds not lower than off by > 3.

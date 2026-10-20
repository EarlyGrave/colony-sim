# Quota (debt), installments, despair, contracts

## Debt = the Metropolis quota `[BUILT]` — `sim/debt/debt_system.gd`, `debt_state.gd`, `data/debt.json`
- Per inmate 120-280 refined (x preset `starting_debt_mult` 0.7/1.0/1.3), **3 % interest per 10-day
  period**: almost unpayable by design (owner 2026-10-19: "that's the point of a prison"). A good factory
  pays 10-30 % by d60 (`tools/debt_model.gd`). Progress comes from petition/shuttle, not from clearing debt.
- **Installments**: 4 refined per inmate per 10-day period, first due d25, 10-day grace. `pay_debt`,
  `set_quota`, `choose_payoff` commands. Surplus carries over.
- **Despair** tracks the schedule, not the balance: missed installment +4/day, met -> decays 10/day; break
  threshold 50; despair >= high -> riot (200 ticks, damages buildings r 12) or dock escape (`escape_weight`).
  Caught escapee: relief 30. Multipliers chain: blocks (Standing) x quest mods (`despair_mult`) x traits.
- Bus: `debt_paid`, `installment_missed` (society cond), `colonist_escaped`. Brother Oto (Q2) carries no debt.
- Text: the UI calls it quota/Collection Day in letters (bible); the data keys still say debt. `[PARTIAL]`:
  renaming is text-only and incomplete (HUD still says "Debt" in places).

## Penance beacons `[BUILT]` — `sim/debt/beacon_system.gd`, `data/beacons.json`, flag `balance.s2_enabled`
`beacon_launcher` (powered) makes beacons from plate + refined; each lives 3 d, cuts debt 3 %/day with
diminishing returns (x0.8), cap 10 %/day, max 8 alive. Design intent (economy doc): on Fight/Remission the
same beacons calm creatures / lower suspicion `[PLANNED]` (no reader yet).

## Contracts and Sector Dispatch `[BUILT]` — `sim/contracts/contract_system.gd`, `data/contracts.json`
- Warden side orders from day 2 every 4 d (ttl 2 d, max 2 open): templates + Frontier Quota (B4). Decline
  or fail raises `anger` -> sanctions. Clean colonies get an essence discount. Commands `accept_contract`,
  `decline_contract`, `deliver_contract`.
- Sector Dispatch (E2, `dispatch_sector`): three tiers (T1 200 food / T2 130 food + 6 refined / T3 60 ore)
  for permanent modifiers: calm (-10 % waves), recruit (+1 colonist), smelting tech.
- Escape path reuses the contract system for covert buyers: credits/suspicion in `sim/society/contraband.gd`
  (`covert_sale`), see [04-society/contraband-suspicion.md](../04-society/contraband-suspicion.md).
  Design doc wanted buyers inside `contracts.json` (C5) — built differently (contraband module). 

## Parole Reviews `[BUILT]` — `sim/research/milestone_system.gd` (reviews), `data/milestones.json reviews`
Rank steps at debt 8 % / 2 waves repelled / debt 14 % (B3), preset-scaled (K2: short -1 wave, hard +1
wave +2 debt), outpost-held step on standard/hard. Reviews 4 "Ledger" (debt left < 75 %) and 5 "Range"
(power surplus x clean air >= 50) (E3). Rewards: lighter audits, rank. Q3 sponsor/bribe hooks (`b3`).

## Legacy and essence delivered
`per_essence_delivered` 0.1 legacy point (`data/meta.json`), see [07-endings-meta/next-sentence-legacy.md](../07-endings-meta/next-sentence-legacy.md).

## Known problems (design, still true)
- One currency, many sinks (installments, research, turrets, chips, petition P4, shuttle parts, gear):
  the only decision is order. Partly answered by petition waivers (F5) and gear costing plates.
- Debt is a tax, not a story: Standing/Walkout/Debt of the Dead (society) add the story layer.

# K5 report — power balance + expedition bot
Flag: `balance.json k5_enabled` (default false). Off = old numbers; goldens untouched (not regenerated).

## Power
- `solar_array` gets `k5_power_gen: 12` (old `power_gen: 25` kept). `PowerSystem.gen_of()` (region K5) uses it only when the flag is on.
- 12 / 40 = 30% of a smelter (was 62.5%). tools/power_model.gd: `gen_of`, `solars_for(n, 0.75)`, K5 table.
- Model, sane build = solars sized for >= 75% of demand:
  | smelters | solars | factor | essence cost |
  |---|---|---|---|
  | 1 | 3 | 0.90 | 144 |
  | 2 | 5 | 0.75 | 240 |
  | 3 | 8 | 0.80 | 384 |
  | 4 | 10 | 0.75 | 480 |

## Expedition bot (`tools/bot_report.gd -- --k5`, region K5)
Home map runs inside a `Campaign`; when a Frontier Quota (cinder_ore demand) is active the bot sends one colonist
with up to 5 raw_food to "ash" (outpost upkeep needs food, else nothing is mined), recalls when the buffer has the ore,
then `_act` delivers. Output per seed adds `frontier_ok= exp_sent=`.
Table (25 days, 5 seeds): seed1 frontier_ok=2, seed2 0 (colonists dead d20), seed3 2, seed4 1, seed5 0 -> 3/5 PASS.

## Tests
tests/test_k5_power.gd: flag-off parity (solar 25), ratio band 0.25..0.35 + sane builds >= 0.75, bot frontier on seeds 1 and 4 (14 days).

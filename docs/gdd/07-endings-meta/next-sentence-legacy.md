# Legacy and Next Sentence (NG+)

## Legacy points `[BUILT]` — `sim/meta/legacy.gd`, `data/meta.json legacy`, `view/panels/meta_screen.gd`
Per day 1, per fulfilled contract 3, per essence delivered 0.1, per freed prisoner 2 / stayed 1 (from the
Submit manifest, F4b), per perk 1, per milestone 1, debt escape points, escape extraction points (F4a);
x `legacy_mult` per ending (Fight 2.0). Spent in the unlock shop: start rules (engineer / taint cap / ore
reserve), start XP, revealed forecast, scout probe, crates (food / parts). Saved in the browser meta store
(`view/meta_store.gd`).

## Next Sentence `[BUILT]` (NG+ batch, F4b) — `sim/meta/meta_state.gd`, `start_opts.gd`, `ng_flavor.gd`, `data/meta.json ng|endings`
- Meta v2: sentence number, history, carried debt, veteran (best colonist: skills, first perk, traits incl.
  scars), up to 4 techs, preset steps up, extra wave mult +0.1 per sentence; sentence 2/3/4+ letters.
- Carry per ending (`meta.json endings`; decided without owner, review — README question 5):
| ending | debt carried | dossier | techs | rename | credits | legacy mult |
|---|---|---|---|---|---|---|
| submit ("New Names") | 0 | yes | yes | yes | — | 1.0 |
| escape ("New Sector") | 25 % | yes | yes | no | 10 % | 1.0 |
| fight | 0 | no | no | no | — | 2.0 |
| remission | 25 % | yes | yes | no | — | 1.0 |
- Two-run chain: run 1 survives 9/10, run 2 6/10 (accepted: the next sentence should be harder).
- NG+ quests: Q11 Previous Tenant (`clue_loop`), Q12 Rolled Over, S5 Old Cells; veteran's block +10.
- (2026-10-20) Dead flag `ng_new_names` removed; the table is the only source.

## Not built
- Three-way Dossier pick Veteran / Archivist (start with a clue) / Debtor (debt x1.5, essence x1.5) `[IDEA]`
  (Q9 design; only the veteran exists).
- Mystery fragment per loop and the fifth-loop Warden quota screen `[IDEA]`.
- Sentence number scaling the Metropolis' interest (GDD §11) `[IDEA]` (only `extra_wave_mult`).

# N1 report: sim/meta NG core (API, published early)
MetaState (sim/meta/meta_state.gd), version 2, `ng` dict: sentence(1=fresh), carry_debt, dossier{name,skills{},perk_id}, techs[], history[{n,seed,days,debt_paid,preset,result}] (cap 20), prev_seed, last_preset.
- `Legacy.ng_snapshot(sim, result, preset_id) -> Dictionary` builds the summary for finish_sentence.
- `MetaState.finish_sentence(summary)`: carry_debt=round(debt_left*0.5), veteran, <=3 techs, history, sentence += 1.
- `MetaState.make_ng_opts() -> {"seed", "opts"}`; `ng_next_preset()`, `ng_seed()`, `has_ng_carry()` (sentence > 1), `ng_cfg()`.
- New opts keys: `carry_debt`, `veteran`{name,skills,perk_id}, `start_techs`, `sentence`; applied in StartOpts._apply_ng; `DebtSystem.add_carry(n)` spreads over inmates.
- Tunables: data/meta.json `ng`: debt_carry_frac, tech_carry, extra_wave_mult.
- MetaStore.save_state is atomic (tmp + rename); corrupt/unknown version -> defaults.

# TW2 report (W2 scent clock + dormancy + HUD ticker)
- threat_system.gd region SC: scent (+per_refine on batch_refined, linear decay); sc_mult()=1/(1+max(0,scent-free)/s0) scales the pollution countdown (_k1_tick, end_wave); dormant_until set on a repelled non-audit wave gates only the pollution wave start; audits bypass it.
- balance.json "scent" (flag enabled; false = old behaviour); needs preset pacing like the pollution clock.
- HUD ticker (_o4_threat_short, region SC): "Nests dormant: X d" / "Scent high: wave in ~X d".
- tests/test_scent_pacing.gd (3 tests: >=30% pull-in, dormancy vs audit, decay). Goldens regenerated (threats part hash only). Quick tests 14/14 green.
- kx_pillar_table d21: baseline 5.6 / throttle 4.0 / mining 4.0 = gap 1.6, identical to HEAD with scent off (HEAD already 5.6/4.0; the design 6.2 is stale, gap>=2 unmet before). Stronger scent (per_refine 0.3-0.6) worsened gap to 1.0-1.4 (earlier waves -> deaths -> calm_after_hit). Shipped gap-neutral values: per_refine 0.15, decay 1.5/d, s0 3, dormancy 2 d clean / 0.25 d polluted.
- factory_eval 60d jobs=3: scent on audit2 5, P1 4, P3 3, launch 1, alive>=8 6/10; scent off 6,4,2,0, 7/10. Both below 9/8/5/3/1 (noise/HEAD drift).
- Open: pillar gap>=2 needs a separate fix.

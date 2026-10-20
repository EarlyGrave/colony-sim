# Rollback points (main merges)
Restore: `git checkout -b restore <sha>` (or reset a branch to it).

| date (UTC) | main SHA | batch | tests |
|---|---|---|---|
| 2026-10-18 20:03 | 837a421 | Logistics 2 | green |
| 2026-10-18 21:05 | 757cd8e | design batch B | green |
| 2026-10-18 22:37 | 96cbe52 | pacing batch K | green |
| 2026-10-18 23:42 | 6de577e | endgame batch E | green |
| 2026-10-19 00:27 | c24980b | shuttle batch S | green |
| 2026-10-19 01:03 | 3e3fb16 | HUD batch U | green |
| 2026-10-19 03:17 | dff9db7 | economy batch Y | green |
| 2026-10-19 03:52 | a5d87c3 | debt batch D | green |
| 2026-10-19 05:39 | d4129cf | plates/progression | green |
| 2026-10-19 10:09 | f1bbfa2 | petition progression + quests (off) | 810 green x2, smoke PASS |
| 2026-10-19 10:55 | 53b561c | quests on (QX) | 814 green x2, smoke PASS |
| 2026-10-19 11:24 | 996000c | quest sheet UI + Q6 start fix | 818 green x2, smoke PASS |
| 2026-10-19 12:55 | 984dbc1 | debt redesign + NG+ + quest UI | 836 green, smoke PASS |
| 2026-10-19 13:33 | 8d46b68 | batch R (quests 3/8/10/11/12) | 859 green, smoke PASS |
| 2026-10-19 | 38d9f1e | LN + inmate society (I1-I4) | 884 green, smoke PASS |
| 2026-10-19 | 53f63b0 | society quests S1-S3 + Q12 fix | 908 green, smoke PASS |
| 2026-10-19 | 3ddda77 | CD + RF/SP tools + PM workbench fix | 910 green, smoke PASS |
| 2026-10-19 | 639a966 | clean smelting (only refining pollutes) | 910 green, smoke PASS |
| 2026-10-19 | 3d5f4ad | PL haul fallthrough to workbench | 910 green, smoke PASS |
| 2026-10-19 | bff5903 | OS map guarantees + SR shelter ration + HM bot | 912 green, smoke PASS |
| 2026-10-19 | 42247d1 | RP + FC: first bot shuttle launch | 912 green, smoke PASS |
| 2026-10-20 | 6671d79 | F2 (fight loop, metro live, gear loot, ending screens) + night sprint 10-19 + LA | 1050 green, smoke PASS, bot alive>=8 6/10 |
| 2026-10-20 | 50fd7cb | F3 (start shiv + wave reward + bot equip, craft-gear economy, traits read, branch tests) | 1077 green, smoke PASS, bot alive>=8 6/10 |
| 2026-10-20 | 2bce7ab | F4 (escape numbers, NG+ carry per ending, revelation polish, last 6 trait stats, mimic name in view) | 1099 green, smoke PASS, bot alive>=8 6/10 |
| 2026-10-20 | 8dee64a | F5 (standing orders flag OFF, petition waivers, fixation flag OFF, quest verbs + r4 story lines) | 1135 green, smoke PASS, bot alive>=8 6/10 |
| 2026-10-20 | c68d72e | F6 (quest beat gating, r4 PA in feed, story fidelity echoes) + FX5 bot fix | 1159 green, smoke PASS, bot alive>=8 7/10 |
| 2026-10-20 | 4e64c98 | F7 (dump-zone tint, reg/fixation signals + PA, petition_pace tool) | 1168 green, smoke PASS, bot alive>=8 7/10 |
| 2026-10-20 | 1a71dac | F8 gear screen (icons, grid inventory, item card, stat names) | 1186 green, smoke PASS, bot alive>=8 7/10 |
| 2026-10-20 | 0f11434 | F9 (path effects, socket cost, gear wear flag OFF + repair, ng_new_names removed) | 1205 green, smoke PASS, bot alive>=8 7/10 |
| 2026-10-20 | ad385e1 | F10 (hints + SeenFlags, late-game perf bench/budget, NEW badges, test isolation) | 1222 green x2, smoke PASS, bot alive>=8 7/10 |

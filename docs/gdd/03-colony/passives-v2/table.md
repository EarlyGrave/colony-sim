# Passives v2 — full table

Generated from the same source as `data/passives_v2.json` (scratch script `gen_passives.py`; edit the JSON and
the table together). 78 passives: 48 minor, 18 notable, 12 keystone. Cost = marks.

| Icon | Name | Tree | Tier | Description | Effect | Requires | How earned |
|---|---|---|---|---|---|---|---|
| ![](../../../../assets/sprites/passive_pit_callouses.png) | Callouses (`p_pit_callouses`) | pit | minor | Hands that stopped bleeding weeks ago. Mining +8%. | mining_speed +0.08 | skill mining>=3 or construction>=3 | 1 mark |
| ![](../../../../assets/sprites/passive_pit_yard_shoulders.png) | Yard Shoulders (`p_pit_yard_shoulders`) | pit | minor | Carries a quarter more per trip. | carry +0.25 | 1 of pit_callouses | 1 mark |
| ![](../../../../assets/sprites/passive_pit_pick_rhythm.png) | Pick Rhythm (`p_pit_pick_rhythm`) | pit | minor | All work 5% faster. | work_speed +0.05 | 1 of pit_callouses | 1 mark |
| ![](../../../../assets/sprites/passive_pit_scaffold_eye.png) | Scaffold Eye (`p_pit_scaffold_eye`) | pit | minor | Builds 12% faster. | build_speed +0.12 | 1 of pit_callouses | 1 mark |
| ![](../../../../assets/sprites/passive_pit_the_mule.png) | The Mule (`p_pit_the_mule`) | pit | notable | Carries half again as much; walks 5% slower. | carry +0.5, move_speed -0.05 | 1 of pit_yard_shoulders | 2 marks |
| ![](../../../../assets/sprites/passive_pit_ore_sense.png) | Ore Sense (`p_pit_ore_sense`) | pit | minor | Ore yield +10%. | ore_yield +0.1 | 1 of pit_pick_rhythm | 1 mark |
| ![](../../../../assets/sprites/passive_pit_salvage_habit.png) | Salvage Habit (`p_pit_salvage_habit`) | pit | notable | Buildings cost 15% less material. | build_cost -0.15 | 1 of pit_scaffold_eye | 2 marks |
| ![](../../../../assets/sprites/passive_pit_long_shift.png) | Long Shift (`p_pit_long_shift`) | pit | minor | Hunger -10%, work +3%. | hunger -0.1, work_speed +0.03 | 1 of pit_the_mule | 1 mark |
| ![](../../../../assets/sprites/passive_pit_quiet_pick.png) | Quiet Pick (`p_pit_quiet_pick`) | pit | minor | Mining noise draws 10% fewer creatures. | threat_attract -0.1 | 1 of pit_ore_sense | 1 mark |
| ![](../../../../assets/sprites/passive_pit_braced_walls.png) | Braced Walls (`p_pit_braced_walls`) | pit | minor | Buildings raised by this inmate have +15% HP. | building_hp +0.15 | 1 of pit_salvage_habit | 1 mark |
| ![](../../../../assets/sprites/passive_pit_vein_reader.png) | Vein Reader (`p_pit_vein_reader`) | pit | notable | Ore yield +20%, mining XP +15%. | ore_yield +0.2, xp_mult_mining +0.15 | 1 of pit_long_shift, pit_quiet_pick, pit_braced_walls | 2 marks |
| ![](../../../../assets/sprites/passive_pit_lifers_back.png) | Lifer's Back (`p_pit_lifers_back`) | pit | keystone | Carry x2, mining +25%. Hunger +25%, walks 15% slower. | carry +1, mining_speed +0.25, hunger +0.25, move_speed -0.15 | 2 of pit_the_mule, pit_salvage_habit, pit_vein_reader | 3 marks |
| ![](../../../../assets/sprites/passive_stacks_rubber_gloves.png) | Rubber Gloves (`p_stacks_rubber_gloves`) | stacks | minor | Operates machines 8% faster. | operate_speed +0.08 | skill operating>=3 | 1 mark |
| ![](../../../../assets/sprites/passive_stacks_valve_feel.png) | Valve Feel (`p_stacks_valve_feel`) | stacks | minor | Machines wear 15% slower under this operator. | machine_breakage -0.15 | 1 of stacks_rubber_gloves | 1 mark |
| ![](../../../../assets/sprites/passive_stacks_nose_plug.png) | Nose Plug (`p_stacks_nose_plug`) | stacks | minor | Mutation risk -15%. | mutation_risk -0.15 | 1 of stacks_rubber_gloves | 1 mark |
| ![](../../../../assets/sprites/passive_stacks_scrub_hands.png) | Scrub Hands (`p_stacks_scrub_hands`) | stacks | minor | Refining waste -5%. | waste_mult -0.05 | 1 of stacks_rubber_gloves | 1 mark |
| ![](../../../../assets/sprites/passive_stacks_slow_pour.png) | Slow Pour (`p_stacks_slow_pour`) | stacks | notable | Contamination per batch -10%; operates 5% slower. | contamination_per_batch -0.1, operate_speed -0.05 | 1 of stacks_valve_feel | 2 marks |
| ![](../../../../assets/sprites/passive_stacks_gauge_eye.png) | Gauge Eye (`p_stacks_gauge_eye`) | stacks | minor | Operates machines 10% faster. | operate_speed +0.1 | 1 of stacks_nose_plug | 1 mark |
| ![](../../../../assets/sprites/passive_stacks_second_skin.png) | Second Skin (`p_stacks_second_skin`) | stacks | notable | Mutation risk -30%; hunger +5%. | mutation_risk -0.3, hunger +0.05 | 1 of stacks_scrub_hands | 2 marks |
| ![](../../../../assets/sprites/passive_stacks_still_air.png) | Still Air (`p_stacks_still_air`) | stacks | minor | Draws 10% fewer creatures. | threat_attract -0.1 | 1 of stacks_slow_pour | 1 mark |
| ![](../../../../assets/sprites/passive_stacks_fume_tolerance.png) | Fume Tolerance (`p_stacks_fume_tolerance`) | stacks | minor | Machinery XP +20%. | xp_mult_operating +0.2 | 1 of stacks_gauge_eye | 1 mark |
| ![](../../../../assets/sprites/passive_stacks_flush_cycle.png) | Flush Cycle (`p_stacks_flush_cycle`) | stacks | minor | Refining waste -10%. | waste_mult -0.1 | 1 of stacks_second_skin | 1 mark |
| ![](../../../../assets/sprites/passive_stacks_cold_hands.png) | Cold Hands (`p_stacks_cold_hands`) | stacks | notable | Contamination per batch -15%. | contamination_per_batch -0.15 | 1 of stacks_still_air, stacks_fume_tolerance, stacks_flush_cycle | 2 marks |
| ![](../../../../assets/sprites/passive_stacks_essence_lung.png) | Essence Lung (`p_stacks_essence_lung`) | stacks | keystone | Waste -20%, operates +20%. Mutation +50%, creatures smell you. | waste_mult -0.2, operate_speed +0.2, mutation_risk +0.5, threat_attract +0.3 | 2 of stacks_slow_pour, stacks_second_skin, stacks_cold_hands | 3 marks |
| ![](../../../../assets/sprites/passive_shop_file_and_vice.png) | File and Vice (`p_shop_file_and_vice`) | shop | minor | Crafts 8% faster. | craft_speed +0.08 | skill crafting>=3 | 1 mark |
| ![](../../../../assets/sprites/passive_shop_scrap_eye.png) | Scrap Eye (`p_shop_scrap_eye`) | shop | minor | Crafting uses 5% less input. | craft_input -0.05 | 1 of shop_file_and_vice | 1 mark |
| ![](../../../../assets/sprites/passive_shop_true_edge.png) | True Edge (`p_shop_true_edge`) | shop | minor | Better craft quality rolls. | craft_quality +0.5 | 1 of shop_file_and_vice | 1 mark |
| ![](../../../../assets/sprites/passive_shop_oil_rag.png) | Oil Rag (`p_shop_oil_rag`) | shop | minor | Own gear wears 15% slower. | gear_wear -0.15 | 1 of shop_file_and_vice | 1 mark |
| ![](../../../../assets/sprites/passive_shop_reloader.png) | Reloader (`p_shop_reloader`) | shop | notable | Uses 15% less ammo. | ammo_use -0.15 | 1 of shop_scrap_eye | 2 marks |
| ![](../../../../assets/sprites/passive_shop_steady_file.png) | Steady File (`p_shop_steady_file`) | shop | minor | Better craft quality rolls. | craft_quality +0.5 | 1 of shop_true_edge | 1 mark |
| ![](../../../../assets/sprites/passive_shop_patch_kit.png) | Patch Kit (`p_shop_patch_kit`) | shop | notable | Repairs 30% faster; machines wear 10% slower. | repair_speed +0.3, machine_breakage -0.1 | 1 of shop_oil_rag | 2 marks |
| ![](../../../../assets/sprites/passive_shop_tinker_hours.png) | Tinker Hours (`p_shop_tinker_hours`) | shop | minor | Crafting XP +20%. | xp_mult_crafting +0.2 | 1 of shop_reloader | 1 mark |
| ![](../../../../assets/sprites/passive_shop_tight_tolerance.png) | Tight Tolerance (`p_shop_tight_tolerance`) | shop | minor | Own gear wears 15% slower. | gear_wear -0.15 | 1 of shop_steady_file | 1 mark |
| ![](../../../../assets/sprites/passive_shop_bench_sense.png) | Bench Sense (`p_shop_bench_sense`) | shop | minor | Crafts 10% faster. | craft_speed +0.1 | 1 of shop_patch_kit | 1 mark |
| ![](../../../../assets/sprites/passive_shop_makers_mark.png) | Maker's Mark (`p_shop_makers_mark`) | shop | notable | Crafted gear is one quality tier higher. | quality_tier +1 | 1 of shop_tinker_hours, shop_tight_tolerance, shop_bench_sense | 2 marks |
| ![](../../../../assets/sprites/passive_shop_signature_work.png) | Signature Work (`p_shop_signature_work`) | shop | keystone | +1 quality tier, gear wear -50%. Crafts 30% slower, +15% input. | quality_tier +1, craft_quality +1, gear_wear -0.5, craft_speed -0.3, craft_input +0.15 | 2 of shop_reloader, shop_patch_kit, shop_makers_mark | 3 marks |
| ![](../../../../assets/sprites/passive_yard_yard_stance.png) | Yard Stance (`p_yard_yard_stance`) | yard | minor | Hit chance +4%. | hit_chance +0.04 | skill shooting>=3 or melee>=3 | 1 mark |
| ![](../../../../assets/sprites/passive_yard_shiv_grip.png) | Shiv Grip (`p_yard_shiv_grip`) | yard | minor | Melee damage +10%. | melee_damage +0.1 | 1 of yard_yard_stance | 1 mark |
| ![](../../../../assets/sprites/passive_yard_duck_and_cover.png) | Duck and Cover (`p_yard_duck_and_cover`) | yard | minor | Dodge +5%. | dodge_chance +0.05 | 1 of yard_yard_stance | 1 mark |
| ![](../../../../assets/sprites/passive_yard_flinch_less.png) | Flinch Less (`p_yard_flinch_less`) | yard | minor | Damage taken -5%. | damage_taken -0.05 | 1 of yard_yard_stance | 1 mark |
| ![](../../../../assets/sprites/passive_yard_brawler.png) | Brawler (`p_yard_brawler`) | yard | notable | Unarmed damage +30%, unarmed hit +10%. | unarmed_damage +0.3, unarmed_hit +0.1 | 1 of yard_shiv_grip | 2 marks |
| ![](../../../../assets/sprites/passive_yard_breath_control.png) | Breath Control (`p_yard_breath_control`) | yard | minor | Hit chance +6%. | hit_chance +0.06 | 1 of yard_duck_and_cover | 1 mark |
| ![](../../../../assets/sprites/passive_yard_thick_skin.png) | Thick Skin (`p_yard_thick_skin`) | yard | notable | Flat armour +1; hunger +5%. | armor_flat +1, hunger +0.05 | 1 of yard_flinch_less | 2 marks |
| ![](../../../../assets/sprites/passive_yard_fast_hands.png) | Fast Hands (`p_yard_fast_hands`) | yard | minor | Attacks 10% faster. | attack_speed +0.1 | 1 of yard_brawler | 1 mark |
| ![](../../../../assets/sprites/passive_yard_count_shots.png) | Count Shots (`p_yard_count_shots`) | yard | minor | Uses 10% less ammo. | ammo_use -0.1 | 1 of yard_breath_control | 1 mark |
| ![](../../../../assets/sprites/passive_yard_scar_tissue.png) | Scar Tissue (`p_yard_scar_tissue`) | yard | minor | Injuries hurt the mood 30% less. | thought_injured -0.3 | 1 of yard_thick_skin | 1 mark |
| ![](../../../../assets/sprites/passive_yard_killers_eye.png) | Killer's Eye (`p_yard_killers_eye`) | yard | notable | Crit chance +8%. | crit_chance +0.08 | 1 of yard_fast_hands, yard_count_shots, yard_scar_tissue | 2 marks |
| ![](../../../../assets/sprites/passive_yard_dead_man_walking.png) | Dead Man Walking (`p_yard_dead_man_walking`) | yard | keystone | Never flees, damage -20%, hit +10%. Mood -8, heals 30% slower. | flee_threshold -1, damage_taken -0.2, hit_chance +0.1, mood_base -8, heal_speed -0.3 | 2 of yard_brawler, yard_thick_skin, yard_killers_eye | 3 marks |
| ![](../../../../assets/sprites/passive_infirmary_clean_rags.png) | Clean Rags (`p_infirmary_clean_rags`) | infirmary | minor | Tend quality +10%. | tend_quality +0.1 | skill medicine>=3 | 1 mark |
| ![](../../../../assets/sprites/passive_infirmary_bedside_manner.png) | Bedside Manner (`p_infirmary_bedside_manner`) | infirmary | minor | Patients get 10% fewer infections. | infection_chance -0.1 | 1 of infirmary_clean_rags | 1 mark |
| ![](../../../../assets/sprites/passive_infirmary_light_sleeper.png) | Light Sleeper (`p_infirmary_light_sleeper`) | infirmary | minor | Rests 15% faster. | rest_gain +0.15 | 1 of infirmary_clean_rags | 1 mark |
| ![](../../../../assets/sprites/passive_infirmary_iron_gut.png) | Iron Gut (`p_infirmary_iron_gut`) | infirmary | minor | Hunger -10%. | hunger -0.1 | 1 of infirmary_clean_rags | 1 mark |
| ![](../../../../assets/sprites/passive_infirmary_triage.png) | Triage (`p_infirmary_triage`) | infirmary | notable | Tend quality +20%, patients heal 15% faster. | tend_quality +0.2, heal_speed +0.15 | 1 of infirmary_bedside_manner | 2 marks |
| ![](../../../../assets/sprites/passive_infirmary_steady_needle.png) | Steady Needle (`p_infirmary_steady_needle`) | infirmary | minor | Tend quality +10%. | tend_quality +0.1 | 1 of infirmary_light_sleeper | 1 mark |
| ![](../../../../assets/sprites/passive_infirmary_thick_blood.png) | Thick Blood (`p_infirmary_thick_blood`) | infirmary | notable | Own wounds heal 25% faster, 15% fewer infections. | heal_speed +0.25, infection_chance -0.15 | 1 of infirmary_iron_gut | 2 marks |
| ![](../../../../assets/sprites/passive_infirmary_calm_voice.png) | Calm Voice (`p_infirmary_calm_voice`) | infirmary | minor | Breaks 15% less often. | break_chance -0.15 | 1 of infirmary_triage | 1 mark |
| ![](../../../../assets/sprites/passive_infirmary_chart_reader.png) | Chart Reader (`p_infirmary_chart_reader`) | infirmary | minor | Medicine XP +20%. | xp_mult_medicine +0.2 | 1 of infirmary_steady_needle | 1 mark |
| ![](../../../../assets/sprites/passive_infirmary_taint_watch.png) | Taint Watch (`p_infirmary_taint_watch`) | infirmary | minor | Mutation risk -20%. | mutation_risk -0.2 | 1 of infirmary_thick_blood | 1 mark |
| ![](../../../../assets/sprites/passive_infirmary_even_keel.png) | Even Keel (`p_infirmary_even_keel`) | infirmary | notable | Base mood +5. | mood_base +5 | 1 of infirmary_calm_voice, infirmary_chart_reader, infirmary_taint_watch | 2 marks |
| ![](../../../../assets/sprites/passive_infirmary_field_surgeon.png) | Field Surgeon (`p_infirmary_field_surgeon`) | infirmary | keystone | Tend +40%, heal +30%. Hunger +20%, combat XP halved. | tend_quality +0.4, heal_speed +0.3, hunger +0.2, xp_mult_shooting -0.5, xp_mult_melee -0.5 | 2 of infirmary_triage, infirmary_thick_blood, infirmary_even_keel | 3 marks |
| ![](../../../../assets/sprites/passive_ledger_count_the_coins.png) | Count the Coins (`p_ledger_count_the_coins`) | ledger | minor | Installments 3% smaller. | installment_pct -0.03 | deed d_first_installment | 1 mark |
| ![](../../../../assets/sprites/passive_ledger_quiet_mouth.png) | Quiet Mouth (`p_ledger_quiet_mouth`) | ledger | minor | Suspicion from your deals -15%. | suspicion_gain -0.15 | 1 of ledger_count_the_coins | 1 mark |
| ![](../../../../assets/sprites/passive_ledger_block_voice.png) | Block Voice (`p_ledger_block_voice`) | ledger | minor | Block Standing gains +25%. | standing_gain +0.25 | 1 of ledger_count_the_coins | 1 mark |
| ![](../../../../assets/sprites/passive_ledger_stoic.png) | Stoic (`p_ledger_stoic`) | ledger | minor | Despair grows 10% slower. | despair_mult -0.1 | 1 of ledger_count_the_coins | 1 mark |
| ![](../../../../assets/sprites/passive_ledger_stash_pocket.png) | Stash Pocket (`p_ledger_stash_pocket`) | ledger | notable | Can hide 2 more units of contraband. | stash_cap +2 | 1 of ledger_quiet_mouth | 2 marks |
| ![](../../../../assets/sprites/passive_ledger_haggler.png) | Haggler (`p_ledger_haggler`) | ledger | minor | Installments 5% smaller. | installment_pct -0.05 | 1 of ledger_block_voice | 1 mark |
| ![](../../../../assets/sprites/passive_ledger_shot_caller.png) | Shot Caller (`p_ledger_shot_caller`) | ledger | notable | Standing gains +50%; breaks 10% more often. | standing_gain +0.5, break_chance +0.1 | 1 of ledger_stoic | 2 marks |
| ![](../../../../assets/sprites/passive_ledger_long_memory.png) | Long Memory (`p_ledger_long_memory`) | ledger | minor | Despair grows 10% slower. | despair_mult -0.1 | 1 of ledger_stash_pocket | 1 mark |
| ![](../../../../assets/sprites/passive_ledger_clean_sheet.png) | Clean Sheet (`p_ledger_clean_sheet`) | ledger | minor | Suspicion from your deals -15%. | suspicion_gain -0.15 | 1 of ledger_haggler | 1 mark |
| ![](../../../../assets/sprites/passive_ledger_scrip_sense.png) | Scrip Sense (`p_ledger_scrip_sense`) | ledger | minor | Covert sales pay 10% more. | sale_price +0.1 | 1 of ledger_shot_caller | 1 mark |
| ![](../../../../assets/sprites/passive_ledger_wardens_ear.png) | Warden's Ear (`p_ledger_wardens_ear`) | ledger | notable | Installments 10% smaller; Standing gains -25%. | installment_pct -0.1, standing_gain -0.25 | 1 of ledger_long_memory, ledger_clean_sheet, ledger_scrip_sense | 2 marks |
| ![](../../../../assets/sprites/passive_ledger_trustee.png) | Trustee (`p_ledger_trustee`) | ledger | keystone | Installments -20%, Standing +50%, suspicion -50%. Despair +30%. | installment_pct -0.2, standing_gain +0.5, suspicion_gain -0.5, despair_mult +0.3, work_speed -0.1 | 2 of ledger_stash_pocket, ledger_shot_caller, ledger_wardens_ear | 3 marks |
| ![](../../../../assets/sprites/passive_key_clean_hands.png) | Clean Hands Doctrine (`p_key_clean_hands`) | pit+stacks | keystone | Contamination -20%, ore +15%. Operates 25% slower. | contamination_per_batch -0.2, ore_yield +0.15, operate_speed -0.25 | 1 of pit_the_mule, pit_salvage_habit, pit_vein_reader; 1 of stacks_slow_pour, stacks_second_skin, stacks_cold_hands | 3 marks |
| ![](../../../../assets/sprites/passive_key_essence_smith.png) | Essence Smith (`p_key_essence_smith`) | stacks+shop | keystone | Craft quality way up, input -20%. Your batches taint +20%. | craft_quality +1.5, craft_input -0.2, contamination_per_batch +0.2 | 1 of stacks_slow_pour, stacks_second_skin, stacks_cold_hands; 1 of shop_reloader, shop_patch_kit, shop_makers_mark | 3 marks |
| ![](../../../../assets/sprites/passive_key_armourers_pride.png) | Armourer's Pride (`p_key_armourers_pride`) | shop+yard | keystone | Gear wear -50%, armour +2, ammo -25%. Builds 20% slower. | gear_wear -0.5, armor_flat +2, ammo_use -0.25, build_speed -0.2 | 1 of shop_reloader, shop_patch_kit, shop_makers_mark; 1 of yard_brawler, yard_thick_skin, yard_killers_eye | 3 marks |
| ![](../../../../assets/sprites/passive_key_walking_wounded.png) | Walking Wounded (`p_key_walking_wounded`) | yard+infirmary | keystone | Damage -10%, heals +50%, shrugs off pain. Tends 20% worse. | damage_taken -0.1, heal_speed +0.5, thought_injured -0.5, tend_quality -0.2 | 1 of yard_brawler, yard_thick_skin, yard_killers_eye; 1 of infirmary_triage, infirmary_thick_blood, infirmary_even_keel | 3 marks |
| ![](../../../../assets/sprites/passive_key_chaplain.png) | Chaplain (`p_key_chaplain`) | infirmary+ledger | keystone | Despair -25%, breaks -25%, mood +3. Learns 15% slower. | despair_mult -0.25, break_chance -0.25, mood_base +3, xp_mult_all -0.15 | 1 of infirmary_triage, infirmary_thick_blood, infirmary_even_keel; 1 of ledger_stash_pocket, ledger_shot_caller, ledger_wardens_ear | 3 marks |
| ![](../../../../assets/sprites/passive_key_quota_hawk.png) | Quota Hawk (`p_key_quota_hawk`) | ledger+pit | keystone | Ore +20%, installments -10%. Draws creatures, mood -4. | ore_yield +0.2, installment_pct -0.1, threat_attract +0.15, mood_base -4 | 1 of ledger_stash_pocket, ledger_shot_caller, ledger_wardens_ear; 1 of pit_the_mule, pit_salvage_habit, pit_vein_reader | 3 marks |

## Deeds (one-off mark sources)

| id | name | trigger | at | marks |
|---|---|---|---|---|
| `d_first_installment` | First Installment | counter:installments | 1 | 1 |
| `d_first_blood` | First Blood | record:kills | 1 | 1 |
| `d_ten_kills` | Ten Notches | record:kills | 10 | 2 |
| `d_fifty_kills` | Yard Legend | record:kills | 50 | 3 |
| `d_three_waves` | Still Standing | record:waves_survived | 3 | 1 |
| `d_ten_waves` | Old Hand | record:waves_survived | 10 | 2 |
| `d_ore_500` | Five Hundred Rocks | record:ore_mined | 500 | 1 |
| `d_ore_2000` | Mountain Mover | record:ore_mined | 2000 | 2 |
| `d_refined_20` | Stack Hand | record:refined | 20 | 1 |
| `d_refined_100` | Stack Boss | record:refined | 100 | 2 |
| `d_repairs_10` | Duct Tape | record:repairs | 10 | 1 |
| `d_got_up` | Got Up Again | record:downs | 1 | 1 |
| `d_rescuer` | Carried a Friend | counter:rescues | 1 | 1 |
| `d_healer_10` | Ten Patients | counter:tends | 10 | 1 |
| `d_debt_cleared` | Paid in Full | counter:debt_cleared | 1 | 3 |
| `d_thirty_quiet` | Thirty Quiet Days | counter:quiet_days | 30 | 2 |

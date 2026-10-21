# Side-quest pool B (SQ17-SQ32)

Same notation as [pool_quests.md](pool_quests.md). `only=` / `avoid=` filter by path (before Q14 there is no
path and only path-neutral templates fire). All texts <= 70 chars per segment.

### SQ17 Paper Trail I: The Margin — clerk | investigate | w2 cd24 | d20+ | len2 exp2 | chain -> SQ18
trig: blk(clerk) alive; day>=20; not_flag line_paper
text: The Clerk found a page that does / not add up. 'Send someone who / reads fine print. Or lies well.'
acc "Send {who}": pick who by charge:t_charge_fraud|trait:t_methodical|lowest_mood; gamble 0.6 (+0.2 if charge fraud). hint "60%: a loophole. Fraud Charge helps."
win: flag line_paper; st clerk +6; mark who 1; ln "A margin note" "'Page 14 is not a rule. It is a suggestion.'"
fail: sus +8; tr who t_reported 40%; ln "Spotted" "The page was watched. So was he."
dec "Leave it": st clerk -3
chain: win -> SQ18 p1 delay 2

### SQ18 Paper Trail II: The Fee — auditor | deliver | w2 cd24 | d22+ | len3 exp2 | line end
trig: flag line_paper
text: The Auditor will 'overlook' the page / for a processing fee: {n} parts. / Receipts are not offered.
params: n = 5+0.1d (5-10)
acc1 "Pay the fee": goal stored(parts,n). hint "-{n} parts. Debt -2%, suspicion -6."
win: it parts -n; debt -2; sus -6; ln "Overlooked" "The page was overlooked. Thoroughly."
fail: sus +8; debt +1
acc2 "Report the Auditor": sus +10; st clerk +8; flag auditor_reported; hint "Clerks +8. Suspicion +10."
dec "Burn the page": st clerk -8; flag paper_burned

### SQ19 Fresh Fish Panic — fresh | protect | w3 cd12 | d6+ | len2 exp1
trig: blk(fresh) alive; colonists<8
text: A new transfer is hiding under a / bunk. The block asks you to keep / them for two nights. They cry.
acc "Take them in": spawn_colonist as guest; wait [ref_dead guest, since(day,2)]. hint "A newcomer for 2 d. If they live, they stay."
win: flag guest_stays (the guest remains a real colonist); st fresh +10; trx guest rescued; ln "They stayed" "They asked for the top bunk. Granted."
fail: st fresh -8; moodb fresh colonist_died; ln "Not that one" ""
dec "No room": st fresh -4
note: room check `colonists < max_colonists` in requires.

### SQ20 The Cull — zealot | hunt | w2 cd14 | d12+ | len4 exp2
trig: threat awakened; kills_total>=3
text: The Zealot counts the tags. 'Bring / down {k} of them. The rest will / know that we are not afraid.'
params: k = 3+0.1d (3-9)
acc "Hunt": snap kills; goal since(kills,k). hint "Kill {k} creatures in 4 d. Zealots +8."
win: st zealot +8; mark @best:melee 1; it essence_rounds +6; ln "Tally kept" "Eleven strokes on the wall."
fail: st zealot -4
dec "We hold": nothing
note: avoid= path_submit (Lifers dislike it): weight x0.3.

### SQ21 Quiet Ward I: The Cough — lifer | cure | w2 cd24 | d14+ | len3 exp2 | chain -> SQ22
trig: sick inmate OR pol>45; not_flag line_ward
text: Half of Block A coughs at night. / The Lifer wants a cure for the / worst of them. 'Before the rest.'
acc "Treat the worst": it cure -1; heal @lowest_mood; flag line_ward. hint "-1 cure. Lifers +8. Then a request."
win: st lifer +8; chain SQ22 p1 delay 2; ln "He sleeps" "The cough moved to the next bunk."
dec "No cure to spare": st lifer -5

### SQ22 Quiet Ward II: Clean Air — fresh | hold | w2 cd24 | d16+ | len3 exp2 | line end
trig: flag line_ward
text: The coughing eases when the stacks / stop. Give them three nights of / clean air. Refine very little.
acc "Go easy": snap refined; at end if since(refined,max:3). hint "<= 3 batches in 3 d. Lift a scar. Pollution -2%."
win: trdel @oldest t_resigned|t_cell_rot|t_lean_years; pol -2; st fresh +6; ln "Quiet nights" "'Withdrawn', says the file. 'Settled.'"
fail: st fresh -4; mod despair_mult 1.1 3
dec "Quota first": st fresh -5

### SQ23 Bell Wire — zealot | build | w2 cd20 | d14+ | len4 exp2
trig: research decoys_1 done; blk(zealot)>=35
text: The Zealot wants a Mourning Bell at / the fence. 'The creatures should / hear something honest.'
params: build mourning_bell n = now+1
acc "Hang it": goal built(mourning_bell,n). hint "Build a bell in 4 d. Zealots +10, waves -5% for 5 d."
win: st zealot +10; mod wave_mult 0.95 5; ln "It rang" "Nothing answered. That was the answer."
fail: st zealot -5
dec "No bells": st zealot -3

### SQ24 Ferry Toll — ferry | smuggle | w3 cd10 | d12+ | len2 exp1
trig: (path=escape or flag contraband_on or day>=24)
text: 'Toll for the east road. {n} calm / units, tonight, no ledger. Say no / and the road finds you.'
params: n = 4+0.06d (4-9)
acc "Pay the toll": it refined_essence -n; sus +4; cr +ceil(n*0.6); hint "-{n} refined. +credit. Suspicion +4."
dec "Refuse": mod wave_mult 1.05 3; hint "Waves +5% for 3 d."
note: path=escape only: n x1.3 and cr x1.4. Instant (no check beat).

### SQ25 Drone Wreck Claim — drone | investigate | bait | w2 cd20 | d24+ | len2 exp2
trig: raids_survived>=1
text: A drone sits cold past the fence. / Its core is intact. Send someone / to strip it before it wakes.
acc "Strip it ({who})": pick who by trait:t_methodical|highest_skill:crafting; gamble 0.65 (+0.1 t_sharp_ears). hint "65%: gear. Else: it wakes."
win: gear any uncommon; it parts +6; ln "Stripped" "The core was still counting. Not any more."
fail: spawn_enemy drone_scout 1; def +4; tr who t_marked 40%
dec "Leave it": nothing

### SQ26 The Procurator's Errand — procurator | deliver | w2 cd16 | d30+ | len4 exp2
trig: quest_done q14_three_forms; only=submit
text: The shuttle voice, politely: / 'A courtesy delivery. {n} refined, / outside the quota. Off the books.'
params: n = 8+0.15d (8-20)
acc "Oblige": goal stored(refined_essence,n). hint "-{n} refined. Debt -2%, a mark. Lifers +4."
win: it refined_essence -n; debt -2; mark @best:crafting 1; st lifer +4; ln "Courtesy logged" "Thank you. We remember."
fail: debt +1; st lifer -4
dec "Quota only": st lifer -2

### SQ27 Strike Sheet — zealot | hold | w2 cd16 | d30+ | len2 exp2 | only=fight
trig: path=fight; blk(zealot)>=30
text: The Zealots pass a sheet around. / Two days: no refining at all. / The Collector counts silence too.
acc "Sign": snap refined; at end if since(refined,max:0). hint "No refining 2 d. Zealots +10, defiance +6."
win: st zealot +10; def +6; flag strike_held; ln "Silence counted" "The ground was quiet. So was the PA."
fail: st zealot -6; mood all left_to_ledger
dec "Keep refining": st zealot -4

### SQ28 Back Door — clerk | smuggle | w2 cd14 | d28+ | len3 exp2 | only=escape
trig: path=escape; blk(clerk)>=30
text: The Clerk found a buyer who asks / no questions: {n} refined, east / gate, third night. Credit is credit.
params: n = 6+0.1d (6-14)
acc "Sell": it refined_essence -n; sus +ceil(n*0.5); at end gamble 0.7 win=[cr +n] lose=[sus +10, it refined_essence +0]. hint "-{n} refined. +{n} credit (70%)."
win: cr +n; st clerk +5
fail: sus +10; st clerk -3
dec "Too hot": st clerk -2

### SQ29 The Warden's Birthday — warden | deliver | w2 cd30 | d12+ | len3 exp2 | max 2
trig: day>=12; stored(meal,5)
text: Notice: the Warden's anniversary is / on the 12th. A cake is expected. / Please supply {n} meals.
params: n = 5+0.1d (5-10)
acc "Bake the cake": goal stored(meal,n). hint "-{n} meals. Debt -1%. The PA says thanks."
win: it meal -n; debt -1; ln "Cake received" "The Warden has no mouth. It was thorough."
fail: debt +1
dec "No cake": sus +2
note: pure humour; reward small on purpose.

### SQ30 It Hums — planet | scrub | w2 cd24 | d20+ | len4 exp2
trig: pol>35; refined>=40
text: The ground hums where the waste / lies. Clear the pits below {x}% and / it may hum something kinder.
params: x = pollution_now - 5 (min 18)
acc "Clear them": goal pollution_below(x). hint "Pollution below {x}% in 4 d. Batches hum less."
win: mod essence_drop_mult 1.1 6; tr @oldest t_waste_kin 25%; ln "Quieter" "The hum dropped a note. It sounded relieved."
fail: pol +2; ln "It hums louder" ""
dec "It is just ground": nothing

### SQ31 A Dead Man's Balance — warden | debt | w2 cd30 | d20+ | len0 exp3
trig: an inmate has died; M1 (Debt of the Dead) fired; not_flag balance_paid
text: {dead}'s balance is outstanding. / It may be settled by a volunteer / or distributed. Both are billable.
acc1 "Volunteer one inmate": debt +1 @lowest_mood; st all +4; flag balance_paid; hint "One inmate's debt +1%. All blocks +4."
acc2 "Distribute it": mood all left_to_ledger; debt +1; hint "All inmates uneasy. Debt +1%."
acc3 "Contest the entry": it plate -4; sus +4; debt -1; hint "-4 plate. Debt -1% on a good day."
note: acc3 gamble 0.5 win=[debt -1] lose=[debt +1]; instant (no check beat).

### SQ32 The Rig — lifer | repair | w2 cd14 | d10+ | len3 exp2
trig: day>=10; stored(plate,3)
text: The Lifer watches the belts rattle. / 'Fix {k} things properly. Not / with tape. Then I will teach you.'
params: k = 4+0.06d (4-8)
acc "Fix them right": snap repairs; goal since(repairs,k). hint "Repair {k} things in 3 d. Lifers +6, parts."
win: st lifer +6; it machine_parts +4; deed @best:crafting d_repairs_10; ln "Done properly" "The Lifer nodded once. That is a speech."
fail: st lifer -3
dec "Tape works": nothing

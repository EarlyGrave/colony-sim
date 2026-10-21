# Side-quest pool A (SQ01-SQ16)

Notation: see [generator.md](generator.md) section 8. Header = `id name — giver | goal [| twist] | w=weight
cd=cooldown days | min day | len=window days | exp=offer expiry days`. `/` in `text` = line break (each segment
<= 70 chars). `n` etc. are build-time params (base+per_day*day, clamped). `win`/`fail` run in the `check`
beat (next dawn). `dec` = decline (also the default on expiry). Block names: lifer, clerk, zealot,
informant, fresh. Values in refined-units: reward ~ 1.25-1.5 x cost.

### SQ01 Ledger Errand — clerk | deliver | w3 cd12 | d8+ | len4 exp2
trig: blk(clerk) alive, blk(clerk)>=30
text: Imre in Block C owes a page to the / lower wing. Carry {n} refined, / no receipt. Receipts are evidence.
params: n = 6+0.12d (4-16)
acc "Carry it": goal stored(refined_essence,n). hint "Hold {n} refined by dawn d+4. Clerks +8."
win: it refined_essence -n; st clerk +8; cr +2; ln "Page delivered" "Block C remembers a quiet courier."
fail: st clerk -6; ln "Page late" "The lower wing filed a complaint."
dec "Not mine": st clerk -2

### SQ02 Elder's Pantry — lifer | deliver | w3 cd10 | d6+ | len3 exp2
trig: blk(lifer) alive; stored(meal,4)
text: The old forms say a block eats / together on the tenth. The Lifer / asks for {n} meals. For the block.
params: n = 4+0.1d (4-10)
acc "Feed the block": goal stored(meal,n). hint "-{n} meals. Lifers +8, calmer 3 d."
win: it meal -n; st lifer +8; mod despair_mult 0.9 3; ln "Table set" "Nobody spoke. Everybody ate."
fail: st lifer -5; moodb lifer left_to_ledger
dec "Not this week": st lifer -3

### SQ03 Spare Parts for Pell — guard | deliver | w2 cd14 | d9+ | len3 exp2
trig: day>=9; stored(parts,3)
text: Guard Pell's cart has a bad axle. / {n} parts, and the cart never saw / you. He remembers favours.
params: n = 3+0.08d (3-8)
acc "Fix his cart": goal stored(parts,n). hint "-{n} parts. Suspicion -8, Pell owes you."
win: it parts -n; sus -8; flag pell_owes; ln "Cart fixed" "Pell: 'Number noted. Under a different heading.'"
fail: sus +5; ln "Cart still broken" "Pell remembers that too."
dec "Report him": sus -4; st informant +4; flag pell_burned
note: flag pell_owes lets EV37 (Pell's tip) fire.

### SQ04 Fence Post — warden | build | w3 cd16 | d10+ | len4 exp2
trig: day>=10; built(turret,1); not_flag sq04_done
text: The perimeter is 'insufficiently / inhabited'. Raise a turret at the / fence. Clerical, not tactical.
params: n = built_now(turret)+1 ; len = 4
acc "Raise it": goal built(turret,n). hint "Build 1 turret in {len} d. Debt -1%."
win: debt -1; mod wave_mult 0.95 3; ln "Perimeter updated" "Form 8-F stamped. Thank you for your service."
fail: debt +1; ln "Perimeter deficient" "A fee has been applied. It is small. It is a fee."
dec "File an objection": sus +3
note: weight x0 if no turret tech; goal uses `built` absolute count.

### SQ05 Courier I: The Handoff — ferry | smuggle | w2 cd30 | d14+ | len2 exp2 | chain -> SQ06
trig: (path=escape or flag contraband_on or day>=20); not_flag line_courier
text: On the guard frequency, at night: / 'Five calm units to the east / fence. No names. Double rate.'
params: n = 5+0.05d (5-9)
acc "Hand it over": it refined_essence -n; sus +6; then check (goal: time-up, gamble 0.75 at end)
win (75%): cr +n; flag line_courier; chain SQ06 p1 delay 2; ln "Paid" "Nobody saw you. The cameras did."
fail (25%): sus +10; st clerk -3; ln "Inspection" "A guard counted twice."
dec "Stay quiet": nothing
hint: "-{n} refined. +{n} credit (75%). Suspicion +6."

### SQ06 Courier II: The Passenger — ferry | escort | w2 cd30 | d16+ | len3 exp2 | chain -> SQ07
trig: flag line_courier
text: 'We have a man who needs a bed. / Three nights. He does not eat / much. He does not sleep.'
acc "Take him in": spawn_colonist as guest; goal wait [ref_dead guest, since(day,3)]. hint "A stranger for 3 d. Keep him alive."
win: remove_colonist guest transfer; cr +6; it parts +4; flag courier_ok; ln "He left" "Bed still warm. Nobody asked who he was."
fail: sus +12; st fresh -5; ln "He died here" "The Ferry will want to talk."
dec "No beds": st clerk -2; flag courier_dropped (ends line)
chain: win -> SQ07 p1 delay 2

### SQ07 Courier III: The Cage — ferry | choice | w2 cd30 | d19+ | len0 exp3 | line end
trig: flag courier_ok
text: A crate arrives with air holes. It / hums when you lean on it. The / Ferry wants it gone. Quietly.
acc1 "Sell it on": cr +8; sus +10; flag cage_sold; hint "+8 credit. Suspicion +10."
acc2 "Report it": debt -2; st clerk -8; flag cage_reported; hint "Debt -2%. Clerks -8."
acc3 "Open it": pol +2; spawn_enemy crawler 2; mark @best:melee 1; flag cage_opened; hint "Two crawlers. A mark if you win."
note: closing bonus deed d_rescuer for acc3 only if no colonist is downed (check at +1 d).

### SQ08 Hold the Fence — zealot | survive | w3 cd14 | d12+ | len5 exp2
trig: day>=12; blk(zealot)>=30; threat awakened
text: The Zealot says the next waves are / a verdict. 'Stand in it. Do not / hide behind the Warden's walls.'
params: W = 2 waves
acc "Stand": snap waves; goal since(waves,2). hint "Survive 2 waves in {len} d. Zealots +10."
win: st zealot +10; mark @best:melee 1; ln "Verdict witnessed" "They chanted. It helped, slightly."
fail: n/a (see note)
dec "Shelter": st zealot -4
note: no waves in the window = no fail, the offer just lapses (st zealot -2); a downed inmate
  during the window at the check: tr @downed t_shellshocked 50%.

### SQ09 Silence for Oto — pilgrim | hold | w2 cd18 | d15+ | len3 exp2
trig: quest_done pilgrims_of_the_slag; pol>25
text: Brother Oto asks for three quiet / days at the stacks. 'Let the / ground hear nothing. Just once.'
params: X = 2 batches max
acc "Go quiet": snap refined; at end if since(refined,max:2). hint "<= 2 refined batches in 3 d. Zealots +8, pollution -2%."
win: st zealot +8; pol -2; mod refine_mult... none; ln "A quiet ground" "Oto left a flower. It was a weed."
fail: mod wave_mult 1.1 3; ln "The stacks spoke" "Oto left. The ground did not."
dec "Not now": st zealot -3

### SQ10 Sick Bay Favour — fresh | cure | w2 cd16 | d10+ | len2 exp2
trig: stored(cure,1); any inmate sick or has t_glowtouched/t_second_skin
text: A newcomer is coughing green. / The Fresh Fish ask for one cure. / It is worth six. They know.
acc "Treat him": it cure -1; heal who. hint "-1 cure. Fresh Fish +10. A calm friend."
win: st fresh +10; trx who calmed_break; ln "He breathes" "He asked your name. Nobody else did."
fail: n/a (instant). acc is the win.
dec "Save the cure": st fresh -6; moodb fresh left_to_ledger

### SQ11 The Informant's Tip — informant | investigate | w2 cd20 | d14+ | len2 exp2
trig: informant; day>=14
text: The Informant leans on the fence. / 'A cache in the north rocks. / Send someone. Not me.'
acc "Send {who}": pick who by trait:t_sharp_ears|t_curious|lowest_mood; gamble 0.55 (+0.15 each of t_sharp_ears,t_curious on who). hint "55%: 10 plate + 6 parts. Else: ambush."
win: it plate +10; it parts +6; informant_standing +5; ln "Cache found" "The Informant looks pleased. Be careful."
fail: spawn_enemy crawler 2; tr who t_marked (50%); ln "Not a cache" "Something was waiting. He is fine. Mostly."
dec "Ignore him": informant_standing -3

### SQ12 Seat Nine I: The Hum — echo | investigate | echo | w2 cd30 | d16+ | len2 exp2 | chain -> SQ13
trig: an inmate has died; pol>25; stored(refined_essence,5); not_flag line_seat9
text: A refined batch repeats a name. / It is {dead}. It asks for / nothing. That is the worst part.
acc "Listen": pick who by trait:t_essence_hum|t_curious|t_dreamer; hint "A night of listening. Mood risk for {who}."
win: mood who quest_uneasy; mark who 1; flag line_seat9; ln "A name, twice" "{dead}. Then the batch went quiet."
fail: n/a
dec "Seal the crate": it refined_essence -5; flag seat9_sealed
chain: acc -> SQ13 p1 delay 2

### SQ13 Seat Nine II: The Bunk — echo | choice | w2 cd30 | d18+ | exp3 | line end
trig: flag line_seat9
text: Someone found {dead}'s bunk made / up, folded corners. Nobody here / makes a bed like that.
acc1 "Keep it made": flag seat9_kept; st lifer +4; hint "Lifers +4. The bed stays."
acc2 "Strip it": it plate +1; mood all quest_uneasy; flag seat9_stripped
acc3 "Bury a name plate": it plate -2; mood all quest_cheer; st lifer +3; st fresh +3; flag seat9_buried
note: seat9_kept/buried add an epilogue echo; no clue flag.

### SQ14 Dust Count — auditor | scrub | w2 cd18 | d18+ | len4 exp2
trig: tier_done(1); pol>40
text: The Auditor wants the dust count / under {x}%. 'I am told the air is / breathable. I am not told by whom.'
params: x = pollution_now - 6 (min 20)
acc "Scrub it down": goal pollution_below(x). hint "Pollution below {x}% in 4 d. Parts + suspicion down."
win: it parts +8; sus -10; ln "Count accepted" "Air: breathable. Source: you."
fail: sus +6; mod audit_parts_mult 1.1 4
dec "It is what it is": sus +2

### SQ15 The Rock Bet — guard | mine | w2 cd12 | d7+ | len3 exp2
trig: day>=7; ore mined by colony > 100
text: Guard Okoro bets {n} ore in three / days, against a shift off the / count. 'You people are fast.'
params: n = 60+3d (60-240)
acc "Take the bet": snap ore; goal since(ore,n). hint "Mine {n} ore in 3 d. Win: gear. Lose: debt +1%."
win: gear any common; sus -3; ln "Paid in kind" "Okoro handed it over without looking."
fail: debt +1; ln "Short" "Okoro wrote a very small number."
dec "No bets": nothing

### SQ16 Guard Duty — guard | ward | w2 cd16 | d11+ | len3 exp2
trig: day>=11; colonists>=5
text: Pell is on report. If nobody dies / on your side of the fence for / three days, the report is lost.
acc "Keep them alive": snap deaths; at end if since(deaths,max:0). hint "No deaths in 3 d. Suspicion -10, Pell owes."
win: sus -10; flag pell_owes; ln "Report lost" "Pell: 'You are a quiet people.'"
fail: sus +6; ln "Report found" "It was always going to be found."
dec "Not our job": nothing

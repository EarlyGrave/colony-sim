# Event pool A (EV01-EV22: camp, weather, essence, society)

Notation: [generator.md](generator.md) section 8; structure: [events.md](events.md) section 2. Header =
`id name — cat | kind | harm N | w=weight cd=cooldown days | min day | T=tension delta`. `req` = requires
(AND), `boost` = weight multiplier, `pick` = colonist pick. `/` = line break (segments <= 70 chars).
`dflt` = option chosen on expiry (exp = card expiry days; notices have none). Thoughts marked * are new
(see integration.md): warm_night* (+4, 2 d), dust_lung* (-4, 2 d), heard_the_hum* (-5, 3 d), found_something* (+4, 2 d).

## Camp life
### EV01 Cards After Lights-Out — camp | choice | harm0 | w3 cd14 | d3+ | T-4
req: colonists>=4. text: A game of cards runs behind the mess. / The stake is tomorrow's potatoes. / Nobody is cheating. Loudly.
a "Deal me in": it raw_food -2; mood all warm_night; st fresh +2. hint "-2 raw food. Warmer night."
b "Break it up": st fresh -2. dflt b, exp 1.

### EV02 Stew Of Uncertain Origin — camp | choice | harm1 | w2 cd16 | d4+ | T+5
req: stored(meal,3). text: The mess stew smells of the pit. / The cook swears it is lunch. The / cook swears a lot.
a "Bin it": it meal -3. hint "-3 meals."
b "Serve it": gamble 0.5 win=[mood all warm_night] lose=[sick @lowest_mood 360, mood all dust_lung]. hint "50%: a fever."
dflt a, exp 1.

### EV03 The Night Watch — camp | choice | harm0 | w2 cd18 | d5+ | T-3
pick who by trait:t_insomniac. boost x2 if has(t_insomniac). req: threat awakened.
text: {who} has not slept in three days. / He walks the fence and counts / things. Some of them move.
a "Post him": scout; trx who night_watch (counter only); hint "Learn where the next wave comes from."
b "Make him sleep": heal who. hint "Rested. No intel."
dflt b, exp 1.

### EV04 Harmonica — camp | notice | harm0 | w2 cd20 | d6+ | T-6
pick who by random. text: {who} found a harmonica in the slag. / It plays one song. It is / the same song. Nobody minds.
fx: mood all quest_cheer; trx who calm_day. max 3.

### EV05 Short Rations — camp | choice | harm1 | w2 cd12 | d5+ | T+4
req: stored(meal,0) or stored(raw_food,0); colonists>=4. text: The pantry count is a number / with no teeth. Someone took / extra. Someone always does.
a "Dock the thief": debt +1 @lowest_mood; st fresh -3; hint "One debt +1%. A block sulks."
b "Share it out": mood all left_to_ledger; hint "Everyone a little hungry."
c "Ask the Warden": sus +2; it meal +4 (after 1 d); hint "+4 meals. Suspicion +2."
dflt b, exp 2.

## Weather and planet
### EV06 Dust Storm — wx | choice | harm1 | w3 cd10 | d4+ | T+5
pick who by trait:t_tar_lungs (optional). boost x2 if has(t_tar_lungs). text: The horizon goes the colour of / old tea. The air tastes of / the pit. Visibility: a rumour.
a "Shelter in": mod refine_mult 0.8 1. hint "Refining -20% for a day."
b "Work through": gamble 0.6 win=[mood all quest_cheer] lose=[sick @lowest_mood 300, mood who dust_lung]. hint "60%: nothing. Else a cough."
dflt a, exp 1.

### EV07 The Long Night — wx | notice | harm1 | w2 cd16 | d6+ | T+3
text: The sun does not come up on / time. The Warden calls it 'a / scheduling matter'.
fx: mod despair_mult 1.1 1; letter "Scheduling" "Dawn will resume. Complaints: see Form 0."

### EV08 Tremor — wx | choice | harm2 | w2 cd18 | d5+ | T+9
req: deposits designated; not wave_pending. text: The ground clears its throat. A / seam over the deposit is / sagging. A prop would hold it.
a "Prop it": it plate -4. hint "-4 plate. No cave-in."
b "Gamble": gamble 0.5 win=[mood all quest_cheer] lose=[cave_in 3]. hint "50%: 3 cells buried for a day."
dflt b, exp 1. max 4.

### EV09 Acid Dew — wx | choice | harm1 | w2 cd14 | d8+ | T+5
req: pol>40; belts>=10. text: The morning dew eats paint. The / belts squeal. This is not rain. / The Warden says it is rain.
a "Wipe the belts": it parts -2; hint "-2 parts."
b "Let it dry": wear 600 random machine; hint "One machine takes damage."
dflt b, exp 1.

### EV10 A Clear Day — wx | notice | harm0 | w1 cd30 | d10+ | T-8
req: pol<25 (clean colonies only). text: The sky clears for one afternoon. / A few of you stand outside / and say nothing. It helps.
fx: mood all quest_cheer; trx all calm_day. max 2. boost x2 if has(t_dreamer).

## Essence and mutation
### EV11 The Batch That Hums — ess | choice | harm0 | w3 cd16 | d10+ | T+2
pick who by trait:t_essence_hum|t_curious. req: refined>=20. text: A refined batch hums a tune. / {who} says it is a name. / Nobody asked which.
a "Write it down": flag ev.hum_batch.record; mark who 1; mood who heard_the_hum. hint "A mark for {who}. He will not sleep."
b "Smelt it": it refined_essence -1; hint "-1 refined. The hum stops."
dflt b, exp 2. note: record unlocks SQ12.

### EV12 Hands That Glow — ess | choice | harm1 | w2 cd20 | d12+ | T+4
pick who by highest_skill:crafting; req: refined>=40; not has(t_clean_blood) on who.
text: {who}'s hands glow after the shift. / It washes off. Mostly. He is / refining faster this week.
a "Let him work": mod refine_mult 1.1 3; tr who t_glowtouched. hint "+10% refining. Creatures notice him."
b "Pull him off": mood who left_to_ledger; hint "No change. He sulks."
dflt b, exp 2.

### EV13 Waste Pit Seep — ess | choice | harm2 | w2 cd18 | d12+ | T+9
req: pol>30; waste>=10 stored. text: A waste pit weeps at the seam. / The ground there has gone quiet. / Quiet is not a good sign.
a "Patch it": it parts -4; it waste -4; hint "-4 parts, -4 waste."
b "Bury it": pol +3; hint "Pollution +3%."
c "Send {who}": pick who by trait:t_waste_kin|t_tar_lungs; pol -1; trx who exposure_illness. hint "Pollution -1%. One exposure."
dflt b, exp 1. max 4.

### EV14 Essence Bloom — ess | choice | harm0 | w2 cd24 | d14+ | T-4
req: pol>35. text: A pale growth blooms on the tailings. / It smells sweet and wrong. The / Zealots call it a message.
a "Harvest": it essence_bloom +3; mood @lowest_mood heard_the_hum. hint "+3 bloom. Someone uneasy."
b "Burn it": pol -1; st zealot -3; hint "Pollution -1%. Zealots -3."
dflt a, exp 2.

### EV15 Fever Dream — ess | choice | harm2 | w2 cd20 | d14+ | T+8
pick who by trait:t_glowtouched|t_second_skin. req: has(one of them). text: {who} sits up at night and talks / in other voices. They are / not asking for help.
a "Tend him": it cure -1 (if held); heal who; trx who calmed_break. hint "-1 cure. He sleeps."
b "Listen": mark who 1; mood who heard_the_hum; mood all quest_uneasy. hint "A mark. The block hears too."
dflt b, exp 1.

### EV16 The Stare — ess | choice | harm3 | w1 cd60 | d30+ | T+14 | max 1
pick who by trait:t_second_skin. req: has(t_second_skin); refined>=120. text: {who} stopped asking for things. / He stands where he is put. / The file says: 'stable'.
a "Let it take him": tr who t_hollow; hint "Hollow: no thoughts, despair frozen, creatures ignore him. Final."
b "Pull him off": mod refine_mult 0.9 3; mood who left_to_ledger; hint "-10% refining 3 d. He stays himself."
dflt b, exp 2.

## Society and blocks
### EV17 Bunk Quarrel — soc | choice | harm1 | w3 cd10 | d8+ | T+4
req: two blocks alive; pick blocks: strong, weak. text: Two blocks want the same bunks. / Neither is wrong. Both are / loud. Someone has a spoon.
a "Mediate": gamble 0.6 win=[bst strong +3; bst weak +3] lose=[bst strong -3; bst weak -3; mood all left_to_ledger]. hint "60%: both up. Else both down."
b "Side with the strong": bst strong +4; bst weak -6.
c "Draw lots": mood all quest_uneasy. hint "Nobody is happy. Nobody bleeds."
dflt c, exp 1.

### EV18 A Favour Remembered — soc | notice | harm0 | w2 cd16 | d10+ | T-4
req: any blk Standing>=60. text: Block elders leave a parcel at the / door. 'For the quiet.' There is a / note. The note says 'quiet'.
fx: it plate +4; it meal +3; bst strong -3 (regress to the middle).

### EV19 The Whisper — soc | choice | harm1 | w2 cd18 | d10+ | T+4
req: informant. text: The Informant was seen at the PA / mast with a pencil. People saw. / People will tell people.
a "Back him": informant_standing +4; moodb !informant left_to_ledger. hint "Informant +4. Others uneasy."
b "Cut him dead": informant_standing -6; sus -3; hint "Informant -6. Suspicion -3."
dflt b, exp 2.

### EV20 Mail Call — soc | notice | harm0 | w2 cd14 | d5+ | T-3
pick who by trait:t_dreamer|random. boost x2 if has(t_dreamer). text: {who} received a letter. The / censor left four words. They / were enough. They were 'we wait'.
fx: mood who letter_home; trx who letter_event; mood all quest_cheer 25%.

### EV21 Initiation — soc | choice | harm1 | w2 cd16 | d8+ | T+4
req: blk(fresh) alive; colonists>=5. text: The old hands are 'welcoming' the / newest transfer. The welcome / involves a bucket and a corner.
a "Step in": st lifer -3; st fresh +6; trx @oldest calmed_break. hint "Fresh Fish +6. Lifers -3."
b "Look away": st fresh -6; tr newest t_hardened 30%. hint "Fresh Fish -6. He toughens."
dflt b, exp 1.

### EV22 The Pool — soc | choice | harm0 | w2 cd18 | d9+ | T+2
pick who by trait:t_greedy. boost x2 if has(t_greedy). text: {who} runs a ration pool on the / next shift change. The odds are / his. The house is also his.
a "Take a cut": it meal +3; st all -2; hint "+3 meals. All blocks -2."
b "Shut it": st clerk -3; mood who left_to_ledger.
c "Join": it meal -2; gamble 0.4 win=[it meal +6] lose=[nothing]. hint "40%: +6 meals."
dflt b, exp 1.

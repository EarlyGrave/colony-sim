# Event pool B (EV23-EV44: Warden, creatures, metro, loot, pasts)

Same notation as [pool_events.md](pool_events.md). New thoughts marked * are listed in integration.md.

## Warden and audits
### EV23 Form 9-A — war | choice | harm0 | w3 cd14 | d8+ | T+2
pick who by charge:t_charge_fraud|trait:t_methodical|random. boost x2 if has(t_charge_fraud).
text: A form arrives for {who} to sign. / It is one page. It has / a second page, stapled behind.
a "Sign": debt +1 who; flag ev.warden_form.sign; mod audit_parts_mult 0.95 8. hint "His debt +1%. Audits cheaper 8 d."
b "Read page two": gamble 0.5 win=[debt -1 who; mark who 1] lose=[debt +2 who]. hint "50%: debt -1% and a mark. Else +2%."
c "Return it blank": sus +3. dflt c, exp 2.

### EV24 The List Is Wrong — war | choice | harm0 | w2 cd24 | d12+ | T+3
pick who by trait:t_charge_wrongful|random. text: The PA reads out the weekly list / of 'persons of interest'. {who} / is on it. He was not here that week.
a "Contest it": it plate -3; sus +2; mood who quest_cheer; flag ev.list_contested. hint "-3 plate. He feels seen."
b "Strike him off yourselves": sus +6; hint "Suspicion +6. Nobody asks how."
c "Let it stand": mood who left_to_ledger; mod audit_parts_mult 0.95 5.
dflt c, exp 2.

### EV25 Interest Notice — war | choice | harm1 | w3 cd20 | d10+ | T+4
req: installment due in <= 3 d; stored(refined_essence,10). text: Notice: interest accrues on / hope not yet delivered. Pay early / and the rate is merely cruel.
a "Pay early": it refined_essence -10; debt -1; st all +2. hint "-10 refined. Debt -1%. All blocks +2."
b "Wait": mod petition_fee_mult 1.05 3. hint "Petition fee +5% for 3 d."
dflt b, exp 2.

### EV26 Surprise Headcount — war | choice | harm1 | w2 cd16 | d14+ | T+5
req: flag contraband_on or sus>=25. text: Guards count the bunks twice. / They do not find the stash. They / find the places where it was.
a "Offer a bribe": it parts -4; sus -8. hint "-4 parts. Suspicion -8."
b "Say nothing": sus +6; mood all quest_uneasy.
dflt b, exp 1.

### EV27 Clerical Error — war | notice | harm0 | w2 cd24 | d10+ | T-6
text: A page was filed under the wrong / planet. Your balance is lower / than yesterday. Do not mention it.
fx: debt -1; ln "Clerical error" "Do not mention it. Mention it quietly." max 3.

## Creatures (non-wave)
### EV28 Tracks In The Slag — crt | choice | harm0 | w3 cd14 | d5+ | T+2
req: threat awakened; not wave_pending. pick who by trait:t_sharp_ears|t_paranoid. boost x2 if has(t_sharp_ears).
text: {who} found tracks in the slag. / Fresh. Heading to the fence and / then not heading anywhere.
a "Follow them": scout; trx who track_follow; mood who quest_uneasy. hint "Learn where the next wave comes from."
b "Wipe them out": mood who quest_cheer. hint "Nothing happens. Probably."
dflt b, exp 2.

### EV29 A Lone Crawler — crt | choice | harm1 | w3 cd10 | d4+ | T+4
req: threat awakened; not wave_pending; scent>=0.3. text: One crawler sits at the fence. / It is not attacking. It is / watching. That is worse.
a "Shoot it": spawn_enemy crawler 1; trx @best:shooting kill_one. hint "A short fight. No reward."
b "Throw it scraps": it raw_food -1; mod wave_mult 0.97 3. hint "-1 raw food. Waves -3% for 3 d."
c "Close the gate": mood all quest_uneasy. dflt c, exp 1.

### EV30 Carrion Season — crt | notice | harm1 | w2 cd24 | d10+ | T+3
req: dormant. text: Something large left its mark on / the tailings and moved on. / The nests are quiet. Suspiciously.
fx: mod wave_mult 1.05 2; mood all quest_uneasy. hint "Next wave +5% for 2 d."

### EV31 A Figure At The Fence — crt | choice | harm2 | w1 cd40 | d25+ | T+10 | max 1
req: quest_done q8_creatures_wear; an inmate has died; not wave_pending.
text: Someone stands at the fence in / a prison coat. It waves. It / knows how to wave.
a "Wave back": mood all quest_uneasy; flag ev.figure_waved; hint "Nothing happens. Everyone remembers."
b "Warning shot": spawn_enemy mimic 1; hint "It leaves. Then it comes back."
c "Open the gate": gamble 0.4 win=[mark @oldest 1; flag ev.figure_in] lose=[spawn_enemy mimic 1]. hint "40%: a mark. Else a mimic inside."
dflt a, exp 1. note: no clue flag; text claims nothing.

### EV32 Burrowing Noise — crt | notice | harm1 | w2 cd16 | d12+ | T+3
req: threat awakened; pick who by trait:t_tunnel_rat optional. text: Something is moving under the / seam. The miners put down their / picks. Then picked them up again.
fx: scout; mood who quest_uneasy; trx who tunnel_warn (counter only).

## Metropolis
### EV33 Overflight — met | choice | harm1 | w2 cd18 | d15+ | T+5
req: defiance>=10 or raids_survived>=1. text: A drone crosses the colony at / forty metres. It does not shoot. / It does not need to.
a "Hide the stock": mood all quest_uneasy; def -2; hint "Defiance -2. Everyone tense."
b "Wave it on": sus +3. hint "Suspicion +3."
c "Fire a shot": def +5; spawn_enemy drone_scout 1; hint "Defiance +5. One scout comes down."
dflt a, exp 1.

### EV34 A Note In The Wreck — met | choice | harm0 | w2 cd24 | d24+ | T+3
req: raids_survived>=1. text: The wreck holds a note in a stiff / hand: 'Return the core and we / forget the rest. Please.'
a "Return the core": def -6; it parts -4; hint "Defiance -6. -4 parts."
b "Keep it": gear any uncommon; def +4; hint "Gear. Defiance +4."
dflt a, exp 2.

### EV35 Leaflets — met | choice | harm1 | w2 cd24 | d18+ | T+4
pick who by charge:t_charge_sedition|trait:t_defiant. boost x2 if has(t_charge_sedition).
text: Leaflets drift over the fence. / {who} reads one aloud. The / Warden's voice goes thin.
a "Burn them": sus -3; moodb zealot left_to_ledger; hint "Suspicion -3. Zealots sulk."
b "Pin them up": def +4; st zealot +4; sus +4; tr who t_agitator 25%; hint "Defiance +4. Zealots +4. Suspicion +4."
dflt a, exp 1.

### EV36 Toll Gate — met | choice | harm2 | w1 cd30 | d30+ | T+9 | only=fight
req: path=fight; defiance>=40. text: A drone drops a plain crate and / a plain number. 'Pay the toll, / or we collect it in person.'
a "Pay": it refined_essence -12; def -8; hint "-12 refined. Defiance -8."
b "Refuse": def +6; mod wave_mult 1.1 4; hint "Defiance +6. Raids +10% 4 d."
dflt b, exp 1.

## Gear and loot
### EV37 Pell's Tip — loot | choice | harm0 | w2 cd20 | d12+ | T-3
req: flag pell_owes. text: Pell leans on the post. 'A crate / fell off a truck near the east / rocks. Not that I saw it.'
a "Collect it": gear any common; sus +2; flag pell_paid. hint "Gear. Suspicion +2."
b "Pass": nothing. dflt b, exp 1. max 2.

### EV38 Supply Crate — loot | choice | harm0 | w3 cd14 | d6+ | T-3
text: A crate lands in the yard with / a parachute and no manifest. / The seal is warm.
a "Open it": gamble 0.7 win=[it plate +6; it parts +4; mood all found_something] lose=[pol +2; mood all quest_uneasy]. hint "70%: plate and parts. Else tainted."
b "Report it": sus -4; it meal +2. dflt b, exp 2.

### EV39 Confiscation — loot | choice | harm2 | w2 cd24 | d20+ | T+6
req: gear_owned>=2; sus>=15. text: A guard asks to 'inspect equipment'. / Armour is equipment. Equipment / is contraband until it is not.
a "Hand over one piece": remove one worn gear (worst); sus -8. hint "Lose one gear. Suspicion -8."
b "Hide it": gamble 0.55 win=[sus +0] lose=[remove all stored gear; sus +10; debt +1]. hint "55%: fine. Else all stored gear seized."
dflt a, exp 1.

### EV40 The Old Hulk — loot | choice | harm1 | w2 cd24 | d14+ | T+4
text: A shuttle hull lies half buried / past the east rocks. Bunks inside. / Some of them are made.
a "Strip it": it parts +8; it machine_parts +2; mood who heard_the_hum; hint "+8 parts, +2 machine parts. One uneasy."
b "Salvage carefully": gamble 0.5 win=[it parts +6; it ai_chip +1] lose=[sick @lowest_mood 300]. hint "50%: parts and a chip."
dflt a, exp 2.

## Pasts (Charges)
### EV41 Old Habits: Arson — past | choice | harm2 | w2 cd24 | d14+ | T+9
pick who by charge:t_charge_arson|trait:t_charge_poaching. once per inmate. req: not wave_pending.
text: {who} stares at the stove. The / flame is very orderly. His file / says 'accidents, twelve'.
a "Give him the torch": wear 800 random machine; pol -1; mark who 1; trx who torch_used. hint "A machine burns. Waste burns too. A mark."
b "Take the matches": mood who left_to_ledger. hint "He sulks. Nothing burns."
c "Send him to the pit": it waste -3; pol -1; hint "A controlled burn: -3 waste."
dflt b, exp 1.

### EV42 Old Habits: Smuggling — past | choice | harm0 | w2 cd24 | d16+ | T+3
pick who by charge:t_charge_smuggling. req: flag contraband_on or path=escape. once per inmate.
text: {who} knows a guard who knows a / cart. 'Everything has a price, / and I know all the prices.'
a "Use his contact": cr +4; sus +6; mark who 1. hint "+4 credit. Suspicion +6. A mark."
b "Keep him out": mood who left_to_ledger. dflt b, exp 2.

### EV43 Old Habits: Desertion — past | choice | harm2 | w1 cd30 | d18+ | T+8
pick who by charge:t_charge_desertion|trait:t_runner. once per inmate. req: not wave_pending.
text: {who} is gone from his bunk. The / gate was locked. The gate is / also not the only way out.
a "Send a search party": gamble 0.6 win=[trx who escape_stopped; tr who t_runner; deed @best:melee d_rescuer] lose=[tr who t_marked; sus +6]. hint "60%: found. Else he is hurt, you are noted."
b "Let him run": xfer who; st all -3; sus -4. hint "He is gone. Blocks -3."
dflt b, exp 1.

### EV44 The Sealed File — past | choice | harm0 | w1 cd60 | d30+ | T+3 | max 1
pick who by trait:t_charge_sealed. req: has(t_charge_sealed). text: A courier brings {who} a thin / folder. 'Your file is ready for / opening. Reading is optional.'
a "Read it": trdel who t_charge_sealed; gamble 0.5 win=[tr who t_charge_wrongful] lose=[tr who t_charge_murder]; mood who quest_uneasy; mark who 1. hint "The Sealed Charge resolves. A mark."
b "Burn it": mood who left_to_ledger; flag ev.sealed_burned. hint "He stays Sealed. The folder does not."
dflt b, exp 3.

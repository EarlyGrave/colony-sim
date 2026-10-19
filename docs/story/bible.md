# Story bible - "Sentence Ended" (canon v2, owner notes 2026-10-19)

## Tone
Bureaucratic dark comedy over real dread. Everything awful arrives as a form. Terse, deadpan, never
cute about death. Humor comes from procedure ("Casualty logged. Nobody asked who."). Quiet beats
are allowed: one line of genuine unease per quest, then back to paperwork. All in-game text English, <=70 chars/line.

## Premise (canon)
The colonists are death-row inmates (grave crimes) who chose life labour over execution. They are
dropped on a far planet to mine and refine Essence for the **Metropolis**, the antagonist faction. The
Metropolis sets a quota; a Metropolis transport shuttle collects refined essence on **Collection Day**
(the existing installment deadlines: every 10 days, the "debt" ledger is the quota ledger). The first
delivery is followed by the first creature wave: refining waste defiles the planet's life and drives it mad.

## The Warden
Voice: a PA system that has read your file and is disappointed in the file. Polite, passive voice,
invoices for feelings. Never shouts, never lies outright - it omits. It is the Metropolis's compliance
module on site: it counts "quota resolved", not lives. It is quietly rooting for the Submit ending because
a closed file scores higher than a dead colony. Late game it slips: a line that sounds almost like
regret, then an apology form.
Samples: "Your quota is a living document. It is also living." / "Congratulations on surviving. Surviving is billable."

## The Metropolis
Capital of the sector; colonies are its mines. Public story: essence is fuel and medicine. Secret: refined
essence is the base of **Lull**, a euphoric that keeps the capital and the colonies from protesting. Lull is
made far away, by hands nobody will miss, because the waste poisons the land. The quota is deliberately
unpayable: a sentence is "credited", never "served". A faster refining pace means more waste, more
madness, more waves - the Metropolis knows and books it as "site attrition".
Faces: the Warden (PA), the Procurator (shuttle voice on Collection Day), the Collector (orbital hub
that sends drone shuttles; the Fight ending's target), the Ferry (smugglers; the Escape ending's buyer).

## Creatures
Not native predators. Refining waste poisons the planet's life. Stage 1: local fauna maddened (crawlers).
Stage 2: mimics - the poison reshapes what it took, and some of what it took were people: earlier
inmates, the first survey crew, your own dead. "Monsters" are the pre-final stage of the poisoning; the
final stage is the planet itself going mad (the Submit ending burns it out). Cleaner refining = slower stages.

## Essence
Concentrated planetary life, mined as ore, refined for the quota. Refining strips it and leaves waste that is
"forgetting": dead ground, silence, then madness. Rarely a refined batch hums or repeats a voice (the
sector's earlier inmates). Mining is safe because ore is still the planet's own; refining is dangerous
because it is theft made visible. Lull is that voice, bottled and sold as calm.

## Inmate archetypes (recurring; cell blocks in data/blocks.json)
1. The Lifer - knows the old forms. Gives hints, never hope. Leans Submit ("a deal is a deal").
2. The Clerk - fraud, reads the quota ledger, finds loopholes and buyers. Leans Escape.
3. The Zealot - believes the creatures are judgment; sabotages refining. Leans Fight.
4. The Informant - reports to the Warden for ration cuts; useful and hated. Leans Metropolis.
5. The Fresh Fish - new transfer, innocent, panics; the colony's conscience. Swings to the majority.
Traits (innate character) are owned by docs/design/progression_traits.md; the bible only references them.

## The revelation (central mystery, revealed in layers during the campaign)
Why keep a colony alive that can never meet quota? Because the product is not the quota - it is Lull, and
the colony's job is to be far away and silent. Layers, each a flag read by the finale:
R1 "Yield" - the Auditor's manifest lists essence by "calm units" (Q6, flag clue_manifest).
R2 "Your handwriting" - a mimic hums an inmate ID (Q8, flag clue_survey_tag).
R3 "The buyer" - skimmed essence sold through the black market; the Ferry asks for "the calm stuff" (S4, flag clue_buyer).
R4 "The slip" - PA maintenance window leaks a quota screen with the word Lull (Q10, flag clue_warden_quota).
R5 "Three Forms" - with any 2 clues held, the Procurator lands with the deal and the Clerk reads the small
print aloud: the three paths open (Q14, data/quests_q14.json). The truth is public in the colony after R5.

## Endings (after R5 the player picks a path; the path is a flag the quests and the shuttle read)
1. **Submit** (bad): keep delivering; the Metropolis ships endgame components; hold the final waves;
   the shuttle takes the inmates out under new names, the planet is burned. "Case closed. Cause: silence."
2. **Fight** (good): refine only for yourselves, ignore Collection Day; Metropolis raids escalate
   (drone shuttles); endgame: survive the big technological assault and destroy the Collector. The planet is free for long.
3. **Escape** (grey, economic): sell essence and derivatives to covert buyers without raising the
   Warden's suspicion; pay the Ferry; evacuate from a point on the world map. This is the existing
   petition/shuttle win, re-skinned: the shuttle is the Ferry's, the fee is their price.
4. Continue (post-win sandbox) and Next Sentence (NG+: a new planet, balance carried forward) stay.

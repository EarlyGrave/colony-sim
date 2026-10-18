# K2 report
- Flag: balance.json k2_enabled=false (default). Table balance.json k2 {outpost_days:2, presets{short_stay:-1 wave/outpost free, standard_term:base/outpost step, hard_time:+1 wave,+2 debt pts/outpost step}}.
- Files: sim/research/milestone_system.gd (# region K2 at end + 3 one-line hooks), sim/campaign/campaign.gd (region K2 _k2_day, called daily from step), data/milestones.json (k2_reviews: review_outpost, kind outpost_days), tests/test_k2_reviews.gd.
- expedition.gd untouched (outpost count taken from campaign maps/ledgers 'lost').
- milestones.k2_preset (default standard_term) must be set by whoever starts a run from the meta preset id (not wired: sim has no preset knowledge). Orchestrator/reconcile: set it.
- Decoy: milestones.k2_consume_decoy() returns true once per newly held outpost period. K1 audit spawn should call: if milestones.k2_consume_decoy(): skip home audit. Not called from K1 code (K1 absent); no runtime dependency.
- k2_essence_exempt() = flag for future hoard clock.
- state_parts adds a 'k2' row only after an outpost day/decoy exists, so flag-off hashes are unchanged; goldens not regenerated.
- Bot accept (>=4/5 seeds reviews) NOT measured: bot has no outpost builder (K5 expedition bot); outpost step is the only new demand.
- Tests: k2 4 tests green; full sharded suite result in orchestrator run.

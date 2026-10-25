# Candidate issue for audit-lead review

**Potential title:** `[IEEE 1800] §16.13.5 — cross-clock sequence .matched endpoint cannot bind`

**Standard:** IEEE 1800-2017/2023 §§16.13.5–16.13.6. The standard permits `sequence_instance.matched` in a sequence expression when source and destination clocks differ; the source endpoint is retained until the first subsequent destination-clock tick.

**Minimal reproducer:** [`p16_13_5_matched_cross_clock.sv`](attempt-02-minimal/input/p16_13_5_matched_cross_clock.sv). Run evidence: Slurm job 3585, both `-g2017` and `-g2023`.

**Observed:** Compile exits 1 in both editions with `Unable to bind wire/reg/memory 'source_seq.matched' in 'main'`. The existing same-clock control `tests/sva_nfa/endpoint_triggered.sv` passes both editions (job 3586), so this reduced result isolates cross-clock use.

**Open-and-closed dedupe:** Searches for `16.13.5` and `matched multiclock` returned no issue. Broader searches found #653 (`.triggered` in a `wait`, §9.4.4) and #719 (sequence match-item subroutine calls, §16.11), which describe different contexts. #446 covers multiclock handoffs and endpoint behavior; the lead should decide whether this is already in its scope or merits a distinct issue. No issue has been filed pending that review.

# Plain multiclock ranged first-clock prefixes — L103

IEEE 1800-2017 and 1800-2023 16.9.2,16.13.1,16.13.2. FOCUSED_TESTED; required broad batch gates remain pending.

Finite ranged first-clock prefixes now use the existing source NFA and parent transport. Plain sequence attempts report their first complete successful path once; unsuccessful children wait for source CLOSE and exhaustion before reporting failure. Implication parents retain universal child aggregation. Reported parents remain allocated until outstanding finite siblings drain; the patch does not physically cancel sibling queues on first success.

Paired runtime tests cover late and early success, all-fail timing, no prefix match, cover once, overlapping attempts, destination backlog, Kill, asynchronous disable, ##0/reversed process order, fixed suffixes and the existing 64-tick construction boundary. A ranged implication with a fixed prefix protects the neighboring universal aggregation path. Nullable first-clock maximal subsequences and unbounded forms receive focused diagnostics. The 64-tick bound is an implementation limit, not an IEEE limit.

An intermediate C++ parenthesis error and the corrected implication timing oracle remain in local evidence. Broader SVA and unbounded/local-action forms remain outside this implemented subset.

[Revision-scoped validation](2026-09-15_plain_multiclock_ranged_prefix_validation.json) records source/artifact hashes and results. Raw logs remain under `evidence/batch-20260915-after-l95`.

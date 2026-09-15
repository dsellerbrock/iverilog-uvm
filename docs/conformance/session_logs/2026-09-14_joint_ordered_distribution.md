# L85 — Joint ordered distributions

The former blanket rejection of `solve ... before` combined with `dist` in
multi-object graphs is replaced by exact staged sampling for the supported
canonical scalar subset. The applicable clauses are IEEE 1800-2017
18.5.4/18.5.9/18.5.10 and IEEE 1800-2023 18.5.3/18.5.8/18.5.9.

Complete component tables are proved before sampling. A distribution is applied
at its subject's stage; previous projections are pinned before resolving later
conditional fibers. Every reachable prefix is preflighted so an unsupported
range cannot make rejection depend on a randomly selected prefix. The existing
one-distribution-per-component, ground-item/state-weight, enumeration and
complete-range boundaries remain explicit. Excluded-range weighting differs in
the edition texts and is not newly implemented by this shared subset.

A rollback regression exposed that graph prefill consumed object RNG state
before Z3 could reject the call. The existing graph transaction now snapshots
and restores each visited object's RNG alongside values and randc history.
Successful consumption and alias visitation are unchanged. Failed-call RNG
rollback is the campaign atomicity contract; this record does not claim IEEE
requires that particular failed-call RNG policy.

Focused paired tests prove earlier/later weighted stages, unequal conditional
fibers, `:=`/`:/` ranges, alias identity, modes, callbacks, exact RNG rollback,
seeded replay, and retained unsupported coupled distributions. The old ordered
limit fixture now requires the supported solve to succeed while preserving all
four over-cap failures and rollback assertions. All eight cases passed through
each ivtest harness; 23 solver/transaction neighbors passed. Commands, artifact
hashes and preserved first failures are in the
[L85 validation record](2026-09-14_joint_ordered_distribution_validation.json).

The initial range oracle combined a conditional count with an unconditional
threshold; review corrected the derivation before the harness. Subsequent
replay failures were retained, diagnosed, and resolved by transaction rollback,
with direct root/child `get_randstate()` checks retained in the final fixtures.

This is focused implementation evidence. Seven-gate batch qualification remains
pending at the user-selected cadence; no new full UVM or application replay is
claimed.

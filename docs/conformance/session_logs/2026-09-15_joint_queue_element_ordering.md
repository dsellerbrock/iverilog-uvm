# L89 — Joint queue selected-element ordering

Constant selected integral and enum queue elements now use the canonical joint
ordering stages after the queue size is proved. This applies to bounded and
unbounded queues under IEEE 1800-2017 18.4, 18.5.9/18.5.10 and IEEE 1800-2023
18.4, 18.5.8/18.5.9; queue retention follows 7.10.

The frontend admits queues through the existing dynamic-element ordering IR.
Runtime admission reads the matching size-variable descriptor, which owns the
queue maximum and element encoding. The first candidate incorrectly parsed a
property type code as that descriptor and was rejected by positive regressions.
The correction reuses the existing descriptor parser and its integral-element
classification, canonical stages, bounds, resize and transaction machinery.

Ten cases pass in each harness, covering probability/fiber oracles,
distributions, signed/enum elements, resize, bounded limits, replay, invalid
indices, ambiguous sizes and enumeration-limit rollback. The mixed cases were
then strengthened with child aliases and a frozen retained element across
actual shrinkage; both editions passed in both harnesses. Thirty-four dynamic,
fixed-array and transaction neighbors passed. Expected bounded-maximum UNSAT
is checked by return value and rollback, without inventing a required message.
See the [validation record](2026-09-15_joint_queue_element_ordering_validation.json)
for exact candidate hashes, commands and preserved first failures.

The shared candidate also contains an unfinished SVA increment; this solver
evidence does not qualify it. Other queue/ordering families remain separate,
and broad batch qualification is pending near ten integrated fixes.

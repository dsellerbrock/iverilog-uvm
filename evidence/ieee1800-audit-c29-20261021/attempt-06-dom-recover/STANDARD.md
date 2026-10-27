# IEEE 1800 rules exercised by the §29.10 probe

IEEE 1800-2017 and 1800-2023 use the same relevant wording:

- §29.5: “In level-sensitive behavior, the values of the inputs and the current state are sufficient to determine the output value.”
- §29.6: “All unspecified transitions default to the output value x.”
- §29.9: “When the input changes, the edge-sensitive cases are processed first, followed by level-sensitive cases.”
- §29.9: “Thus, when level-sensitive and edge-sensitive cases specify different output values, the result is specified by the level-sensitive case.”
- §29.10, Table 29-3 example: “When the edge-sensitive case is processed first, followed by the level-sensitive case, the output changes to 1.”

The recovery steps first assert clear at t1, so the level-sensitive row establishes known state 0 after any unmatched time-zero initialization transitions. The edge control then releases clear while the clock is low (the `0 ? f` row holds state) and applies a clean rising edge. The collision instance applies the same rising edge while clear remains asserted, so the edge row requests 1 and the level row requests 0 at once.

Page references: 2017 pp. 833, 837–838; 2023 pp. 865, 869–870.

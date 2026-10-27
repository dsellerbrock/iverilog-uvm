# IEEE 1800 PLA system tasks

IEEE 1800-2017 §20.17.1–§20.17.4 and 1800-2023 §20.16.1–§20.16.4 specify the PLA system tasks and their personality memory.

- **Array row encoding:** 2017 §20.17.4 / 2023 §20.16.4 state: “A 1 means take the input value, and a 0 means do not take the input value.” Each memory row selects the input terms used for one output row; the standard's example maps `1100000` to `a1 & a2`. For OR forms, the selected inputs are ORed instead of ANDed.
- **Asynchronous re-evaluation:** 2017 §20.17.1 / 2023 §20.16.1 state that asynchronous evaluations occur whenever an input term changes value or any word in the personality memory changes.
- **Dynamic personality updates:** 2017 §20.17.3 / 2023 §20.16.3 state that the new personality is reflected on the outputs at the next evaluation.
- The memory is declared with width equal to input-term count and depth equal to output-term count; input terms, output terms, and memory are specified in ascending order (§20.17.3 / §20.16.3).

These rules predict `P1 10 10`, `P2 11 11`, and `P3 00 01`; after changing `mem[2]` from `0011` to `0001` while `in=0001`, asynchronous re-evaluation predicts `P4 01 01`.

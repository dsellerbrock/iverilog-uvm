# IEEE 1800 aggregate conditional rule

Both IEEE 1800-2017 §11.4.11 and IEEE 1800-2023 §11.4.11 say: “The conditional operator can be used with nonintegral types (see 6.11.1) and aggregate expressions (see 11.2.2) using the following rules.” For all other cases, the first and second expression types shall be equivalent (§6.22.2).

Both editions also say that for nonintegral and aggregate expressions, if `cond_predicate` is ambiguous and the expressions are not logically equivalent, aggregate array values (except associative arrays) with equal element counts are combined element by element: equal elements are returned; differing elements return the Table 7-1 value for the element type. This is why qx uses an `x` condition and expects equal element `1` to remain `1` and element `5` vs. `7` to merge with an `x` at the differing bit positions.

2017 text source: local IEEE 1800-2017 PDF, §11.4.11, extracted lines 17277–17324 in `/tmp/ieee1800-2017-audit.txt`.
2023 text source: local IEEE 1800-2023 PDF, §11.4.11, extracted lines 18390–18423 in `/tmp/ieee1800-2023-audit.txt`.

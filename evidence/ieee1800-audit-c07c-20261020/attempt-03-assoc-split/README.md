# Split associative-array probe

Run the six isolated files in `tests/1800_audit/c07/a[1-6]_*.sv` under both IEEE editions. Every file prints and flushes a `BEGIN` marker before exercising its single feature. Each compile and runtime command has a 30-second timeout.

Clause text checked locally in both standards PDFs: §7.8.3 says “A null index is valid.” Section 7.8.5 says “Declared indices shall have the equality operator defined for its type to be legal,” and “real or shortreal data types, or a type containing a real or shortreal, shall be an illegal index type.” Section 7.8.5 also gives an unpacked `struct` as an associative-index example. Probe type `U` contains only `byte` and `int` members. The quoted wording is the same in 2017 §7.8.3/§7.8.5 (p. 156) and 2023 §7.8.3/§7.8.5 (pp. 164–165).

The a2 source follows the lead's operation `ak[kd], ak.size()`. Given two base-key entries plus one derived-key entry, its expected output is `A2 3 3`; the lead's table listed `3 1`, which is inconsistent with the stated expression and inserted values.

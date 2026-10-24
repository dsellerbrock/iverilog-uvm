# §7.12 remainder without the blocking nested reduction

`p07_12_methods_r.sv` is byte-identical to `p07_12_methods.sv` except for removal of the `m` declaration and R4 statement; the exact diff is `methods-r-only.diff`. This allows all other locator, ordering, iterator-index and reduction checks to run.

`n07_12_shuffle_with.sv` tests the §7.12.2 rule that specifying `with` for `shuffle()` is a compiler error.

Before evaluating R5/R6, the exact 2017 and 2023 §7.12.3 sentence was checked: “The method returns a single value of the same type as the array element type or, if specified, the type of the expression in the with clause.” Therefore `w.sum` returns the array element type `bit [7:0]` (300 wraps to 44), while `w.sum with (int'(item))` returns the with-expression type (300).

Expected stdout is `input/expected.txt` with the helper's trailing spaces preserved. Each compile/run has a 30-second timeout; resources are 1 CPU, 1 GiB, 20 minutes. Raw diagnostics/stdout/stderr are saved by the job.

## Archive integrity

- `results-3513.tar.gz`: 10068 bytes; SHA-256 `53861e731a8cb815e71cb4703b7ce07c565743fbdee08c7f34fb75a2e8eb6385`.

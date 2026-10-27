# IEEE 1800 §7.11 / §20.7 array-query probe

The positive probe covers `$dimensions`, `$unpacked_dimensions`, `$left`, `$right`, `$low`, `$high`, `$increment`, and `$size` on packed, unpacked, dynamic, queue, and integral-key associative arrays. It also runs the standards' constant-expression and §20.7.1 multiple-variable-dimension examples. Run under `-g2017` and `-g2023`.

The lead-provided string-key associative-array `$size` example was corrected after direct standards review: IEEE 1800-2017 §20.7 p.602 and 1800-2023 §20.7 p.631 restrict query functions on associative-array dimensions to integral index types. The positive probe uses `int aa[int]`; [`n07_11_nonintegral_assoc_query.sv`](../../../../tests/1800_audit/c07/n07_11_nonintegral_assoc_query.sv) checks that `$size` on `int aa[string]` is rejected in both editions. [`n07_11_dynamic_dimension_query.sv`](../../../../tests/1800_audit/c07/n07_11_dynamic_dimension_query.sv) checks the §20.7.1 error for querying a variable-sized dimension with dimension number greater than 1.

Expected positive output, subject to confirmation against the cited clauses:

```text
D 2 0 3 2
U1 2 5 2 5 -1 4
U2 0 1 -1 2
P 3 1 4 8
Y 3 0 2 1
A 0 2147483647 5 9 -1 2 <all x bits>
S 16 16
M 3 3 4 0 5
X <all x bits>
```

Both negative sources should fail to compile in both editions. §20.7 in both editions specifies `$increment` as 1 when left ≥ right and −1 when left < right for fixed-size dimensions; a query whose dimension argument is out of range returns `'x`. Full excerpts and page references are in [`STANDARD.md`](STANDARD.md).

# IEEE 1800 longest static prefix and `always_comb`

IEEE 1800-2017 and IEEE 1800-2023 §11.5.3 define a static indexing select as one whose prefix is static and whose index is a constant expression. The examples in both editions say:

> `m[1][i]` — longest static prefix is `m[1]`
>
> `m[p][1]` — longest static prefix is `m[p][1]`
>
> `m[i][1]` — longest static prefix is `m`

Here `p` is a localparam and `i` is a variable. The §11.5.3 examples are identical in both editions.

IEEE 1800-2017 §9.2.2.2 says: “The variables written on the left-hand side of assignments shall not be written to by any other process. However, multiple assignments made to independent elements of a variable are allowed as long as their longest static prefixes do not overlap (see 11.5.3).”

IEEE 1800-2023 §9.2.2.2 says: “The variables assigned on the left-hand side of assignments shall not be assigned by any other process. This includes variables assigned within functions called by the procedure but not those assigned within tasks called by the procedure. However, multiple assignments made to independent elements of a variable are allowed as long as their longest static prefixes do not overlap (see 11.5.3).”

The positive writes `m[0][1]` and `m[1][0]` have distinct static prefixes. In n1, `m[i][0]` has prefix `m`, which overlaps the other write. In n2, `m[0][p]` and `m[0][1]` identify the same element and prefix.

Text sources: local IEEE 1800-2017 PDF §§11.5.3 and 9.2.2.2 (extracted lines 18041–18083 and 13014–13023); IEEE 1800-2023 PDF §§11.5.3 and 9.2.2.2 (lines 19184–19226 and 14083–14096).

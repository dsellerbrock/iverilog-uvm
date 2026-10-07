# IEEE 1800-2023 array `map()` — bounded qualification

`map()` runs under strict `-g2023` for the tested fixed, dynamic, queue, and
associative cases, including unpacked-array-valued `with` results. Strict
`-g2017` continues to reject it. This is bounded feature evidence, not a claim
that every legal `map()` interaction or the complete array-method clause is
qualified.

## Current image

- `local-install/bin/iverilog`: `1e80ff0dad9a2fe60a4885a6d540ae8fe77a743bd8f42d359b26247b1b786a50`
- `local-install/lib/ivl/ivl`: `c6235119c70f3ee61bd4a320a6e149214701f5856a94f9629e6104cac52f939b`
- `local-install/bin/vvp`: `1d2955a4d7e886608a8f343401619940e1b3adf52bafc66b5eb13d58db9d32b5`
- `local-install/lib/ivl/vvp.tgt`: `dcdf2a5a5aeef3422952a7ff61ad874cb577beacf120e27b9244d9dd599c7243`

## Exercised behavior

- Dynamic arrays and queues, including empty inputs; default `item`, custom
  iterator and index-method names, and two-array indexing.
- Fixed arrays preserve descending nonzero ranges; fixed multidimensional
  input maps rows through `row.sum()` and preserves the outer range.
- Fixed-array-valued `with` results work for fixed matrix, dynamic, queue, and
  associative receivers. The tests check row contents, declared ranges and
  keys, empty results, and a second map over containers holding mapped rows.
- Associative arrays preserve string keys, including empty input and a
  custom key alias.
- The `with` expression's tested result types include integral, bit, string,
  real, and unpacked-struct values. The tests check actual values, not only
  compilation.
- The original `values.map() with (item * 2)` reducer now passes in `-g2023`
  and fails compilation in strict `-g2017`.

## Focused results

The paired map lists each pass 4/4:

```sh
PATH=../local-install/bin:$PATH python3 vvp_reg.py --strict regress-array-map-2023-focus-vvp.list
PATH=../local-install/bin:$PATH perl vvp_reg.pl --strict regress-array-map-2023-focus-legacy.list
```

Adjacent array-method checks pass on the same source-built image: min/max and
fixed-array reductions 6/6 JSON; unique and associative unique 15/15 JSON and
19/19 legacy; find-last 1/1 JSON; selected find-last/min-max/reduction cases
5/5 JSON and 5/5 legacy; class fixed-array min/max 6/6 JSON; and OpenTitan
array-of-containers 18/18 in both harnesses. No broad suite or application
corpus was run for this increment.

## Remaining boundary

The tested unpacked-array-valued results close the whole-row case that was
previously rejected during elaboration. Additional legal result types and
interactions still need broader qualification; these focused checks do not
establish complete §7.12.5 conformance or application-wide behavior.

## Original RED baseline

Before the implementation, both strict 2017 and 2023 compilers rejected
`values.map() with (item * 2)` with the missing-method diagnostics below:

```text
error: Method map is not a dynamic array method.
error: Method map is not a dynamic array method.
error: Object main.values has no method "map(...)".
```

The local IEEE 1800-2023 §7.12.4–7.12.5 text was reviewed directly. It defines
the optional index-method name, requires `with`, gives mapped elements the
self-determined type of the `with` expression, and preserves the source range
or associative index set. IEEE 1800-2017 §7.12 has no `map()` method.

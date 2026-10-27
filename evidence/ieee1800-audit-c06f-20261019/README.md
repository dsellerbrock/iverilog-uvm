# IEEE 1800 §§6.22–6.23 probes

Run 2026-10-19 on Darwin ARM64 using `~/codex-supervisor/localrun`; every
compile and simulation had a 60-second per-test timeout. Audit checkout
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; compiler source
`b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus SHA-256
`7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
The issued probes were identical under `-g2017` and `-g2023`.

The localrun captures and all compiler/runtime logs are in `attempt-01/`
through `attempt-05/`. Elapsed time / peak RSS: 11.31 s / 46,727,168 bytes
(first matrix plus nine GitHub searches); 0.56 s / 16,941,056 bytes; 1.55 s /
16,957,440 bytes; 0.53 s / 16,891,904 bytes; 0.78 s / 16,990,208 bytes.

## Results

- §6.22 instance-type example `p06_22a_instance_types.sv` compiles and runs
  in both editions, printing `T22 v1=5`. Distinct module-instance struct
  types reject assignment. Class-handle/int assignments reject in both
  directions.
- `neg/n06_22_chandle_to_int.sv` compiles with no diagnostic in both
  editions. Its issue status is pending lead dedupe against closed issue #13.
- Basic §6.23 type declarations, `var type(...)`, type parameters and
  non-evaluation of a function-call operand pass in `p06_23f_type_declarations.sv`
  in both editions: `DECL c=4 d=4 zbits=32 T=13 bus=13 W=13 calls=0`.
- The standard's cast example form fails in both editions:
  `p06_23c_type_cast.sv` gets the “type() operator is only supported in ==,
  !=, ===, !==, or case matching” diagnostic, then “Cast size expression
  must be constant and greater than zero”.
- The standard's generate-case example form fails in both editions:
  `p06_23d_generate_case.sv` gets the same unsupported-use diagnostic and
  “Cannot evaluate genvar case expression”.
- Type comparisons on struct, union or array types reject in both editions:
  `p06_23e_type_aggregates.sv` reports that matching for those operand shapes
  is not modeled. It includes the standard's matching/nonmatching examples.
- Scalar matching checks run, but range direction is ignored:
  `p06_23b_type_scalar.sv` reports `FAIL range_direction` (4 passes, 1 fail);
  `type(ETYB) != type(byte)` evaluates false, contrary to the §6.22.1(e)
  example. The direct multidimensional packed-array mismatch control
  `p06_23g_array_mismatch.sv` also prints `MATCH=1` in both editions although
  the standard's §6.22.1(f) example says the types do not match.
- `neg/n06_23_type_hier_ref.sv` compiles in both editions despite the §6.23
  ban on hierarchical references inside `type()`. The non-type comparison
  and missing-`var` negative controls reject in both editions.
- The first combined positive `p06_23a_type_op.sv` was blocked by unsupported
  cases before it could exercise the rest; reduced probes `p06_23b`–`p06_23g`
  isolate those results.

## Dedupe and issue status

All states were searched for `type operator`, `type()`, `type reference`,
`type compatible`, `type matching`, `type equivalence`, `var type`,
`type comparison`, and `typedef struct unique instance`. The 19 unique hits are
in [`attempt-01/dedupe-unique.txt`](attempt-01/dedupe-unique.txt). Likely
matches #19 (broad, old language-edge tracker), #611 (class-scoped type
parameter cast), and #728 (array value equality) were reviewed; none covers
these type-operator semantics.

The lead classified six findings separately. Six issues were created and
verified OPEN with the `1800-audit` label:
[#754](https://github.com/dsellerbrock/iverilog-uvm/issues/754) (`type()` cast),
[#755](https://github.com/dsellerbrock/iverilog-uvm/issues/755) (generate-case
`type()`), [#756](https://github.com/dsellerbrock/iverilog-uvm/issues/756)
(aggregate type matching), [#757](https://github.com/dsellerbrock/iverilog-uvm/issues/757)
(packed range/dimension matching), and [#758](https://github.com/dsellerbrock/iverilog-uvm/issues/758)
(hierarchical reference inside `type()`). [#759](https://github.com/dsellerbrock/iverilog-uvm/issues/759)
covers the chandle-to-integral assignment gap.

The lead's all-state search for `chandle` returned closed #13. Its scope and
resolution comment cover DPI pointer round-tripping, not assignment to an
incompatible SV type. The distinct gap is filed as #759.

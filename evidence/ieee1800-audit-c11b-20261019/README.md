# IEEE 1800 §11.4.12–§11.4.14 audit

Probes ran on macOS Darwin ARM64 under `~/codex-supervisor/localrun` on
2026-10-19. Checkout HEAD: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`;
built compiler source: `b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus
13.0-devel SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
Every reported result matched under `-g2017` and `-g2023`.

## §11.4.12–§11.4.13

`p11_04d_cat_inside_stream.sv` passes 22/22 in each edition after isolating
an unsupported unpacked-array source expression in its `u3` check. It covers
packed concatenation and replication (including zero replication and one
function evaluation), string concatenation/replication, `inside` with values,
arrays, wildcards and ranges, generic stream ordering and slice sizes, nested
streaming, queue targets, and a streaming `with` range. The original combined
probe and its first compile logs remain in `attempt-03/`; the corrected full
probe is `tests/1800_audit/c11/p11_04d_cat_inside_stream_reduced.sv`.

## §11.4.14.3 fixed unpacked-array source

The initial combined probe failed at the standard's direct streaming example.
The lead requested four reducers to distinguish array access, streaming LHS
support, fixed-array source handling and an equivalent explicit concatenation.
They ran with:

```sh
~/codex-supervisor/localrun 180 bash evidence/ieee1800-audit-c11b-20261019/attempt-04/run-probes.sh
```

Wall/RSS: 1.80 s / 16,908,288 bytes. Results, identical in both editions:

- `r11_14_a_array_rw.sv`: compile/run pass, `A 1 2 3 4`.
- `r11_14_b_stream_packed.sv`: compile/run pass, `B 1 2 3 4`.
- `r11_14_c_stream_array.sv`: compile fails with `error: Array up needs an array index here.`
- `r11_14_d_concat_rhs.sv`: compile/run pass, `D 1 2 3 4`.
- Reduced `p11_04d_cat_inside_stream.sv`: compile/run pass, `RESULT pass=22 fail=0`.

The fixed unpacked-array form is the §11.4.14.3 example in IEEE 1800-2017
pp. 276–277 and 1800-2023 §11.4.14.3. The lead classified it as a distinct
conformance gap: [#772](https://github.com/dsellerbrock/iverilog-uvm/issues/772)
tracks streaming unpack from a fixed unpacked array. The lead also required a
cross-reference comment on [#747](https://github.com/dsellerbrock/iverilog-uvm/issues/747),
which covers fixed-array bit-stream casts under §6.24.3; it uses a similar
array-index diagnostic but is a different construct. [#41](https://github.com/dsellerbrock/iverilog-uvm/issues/41)
is closed and covers streaming LHS with packed sources; the packed-source
control still passes.

The reducer suite, compile/run logs, hashes, and localrun resource report are
in `attempt-04/`. The source was minimized before issue filing. Dedupe searches
for streaming, stream operator, concatenation, replication, inside, with
expression, and unpacking are preserved in `attempt-03/`; exact all-state
searches for `streaming fixed unpacked array`, `streaming unpacked array`,
`stream unpacked array source`, and `streaming concatenation array source`
are in `attempt-04/`. #19 CLOSED mentions the separate fixed streaming-RHS
work, #41 CLOSED covers streaming LHS with packed sources, and #747 OPEN
covers explicit bit-stream casts; none covers a streaming LHS whose source is
a fixed unpacked array.

## Classification

- §11.4.12, §11.4.12.1, §11.4.12.2, and §11.4.13: IMPLEMENTED (tested subset).
- §11.4.14 and §11.4.14.1–§11.4.14.4: PARTIAL. The fixed unpacked-array
  source gap is tracked by [#772](https://github.com/dsellerbrock/iverilog-uvm/issues/772).
  The no-cast arithmetic operand and non-bit-stream `real` source are accepted
  without diagnostics, tracked together in
  [#777](https://github.com/dsellerbrock/iverilog-uvm/issues/777). The wide
  target, too-few source bits, and zero slice-size negatives reject as required.
  Other unprobed source/destination and illegal forms remain UNASSESSED.

The §11 audit issue total is 8: two under §11.3.1, one under §11.4.14.3,
one under §11.4.14, and four under §11.12. The cumulative audit total is
46 new issues above the 89-open-issue baseline. GitHub shows 135 issues with
the `1800-audit` label open. See the matrix for the clause rows.

## §11.4.14 illegal cases

Five negatives ran in both editions under `localrun` with 60-second
per-compile timeouts; total wall/RSS was 1.24 s / 16,973,824 bytes. Raw logs,
runner and source copies are in `attempt-05-illegal/`:

- `n11_14_wide_target.sv`: rejected (96-bit stream does not fit 32-bit target).
- `n11_14_few_bits.sv`: rejected (23 source bits cannot fill a 96-bit target).
- `n11_14_slice_zero.sv`: rejected (slice size must be a positive constant integral expression).
- `n11_14_operand_nocast.sv`: accepted with no diagnostic.
- `n11_14_non_bitstream.sv`: accepted with no diagnostic.

Minimal runtime probes in `attempt-06-illegal-runtime/` confirm the silent
behavior in both editions: using the stream in arithmetic prints `OP x=6`;
streaming `real r=1.5` into a 64-bit destination prints `RL
x=0000000000000000`. This is tracked by #777. Dedupe searches over all issue
states are stored in attempts 05–06; #41, #746, #747, and #772 were inspected
and are related but cover different constructs.

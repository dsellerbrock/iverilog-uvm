# IEEE 1800 §§6.11–6.14 audit probes

Run on 2026-10-19 on macOS Darwin ARM64 under `~/codex-supervisor/localrun`.
Each compile and simulation used `scripts/run_with_timeout.py 60`. Audit
checkout: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; compiler source:
`b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus SHA-256:
`7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256: `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
Both editions produced identical outcomes.

## Results

- **§6.11 integer types:** the corrected `p06_11a_integer_real.sv` passes
  18/18 checks in both `-g2017` and `-g2023`: tested integer widths and
  default signing, 2-state/4-state conversion, sign/zero extension,
  truncation, and real/integer conversions.
- **§6.12 real types:** `p06_11b_real_details.sv` confirms shortreal value
  1.5 and realtime value 3.25 survive assignments and comparisons; tested
  half-away-from-zero conversion and X/Z-to-zero behavior pass. The three
  prohibited real uses—edge control, bit select, and index—reject in both
  editions.
- **`$bits` compatibility:** Icarus reports 1 for real, shortreal, and
  realtime expressions. This is not classified as a conformance gap: §20.6.2
  defines `$bits` in terms of a bit stream and points to §6.24.3, whose list
  of bit-stream types excludes real types. See the [compatibility note](../../docs/conformance/DISCOVERED_DEBT.md#ieee-audit-compatibility-note).
- **§6.13 void:** using a void function result as a value rejects in both
  editions. Valid void-function calls and `void'()` casts pass in the core
  §6.14 probe.
- **§6.14 chandle:** legal default/null, comparison, assignment,
  associative-array, class-property, function argument/return, and tagged
  union uses pass in both editions (`p06_14b` reports 8/8; `p06_14c` prints
  both tagged-union assignments). All seven prohibited-use probes compile in
  both editions. Chandle-to-int is already #759. The other six are reported
  separately as #763 (arithmetic expression, continuous assignment, and
  sensitivity/event expression) and #764 (module port, packed struct member,
  and untagged union member).

The initial broad attempt in `attempt-01/` had two invalid `$bits` width
expectations and used a malformed combined tagged-union probe. Those results
are retained for traceability and are not treated as conformance evidence.
`attempt-02/` isolates real and legal chandle behavior. `attempt-03/run.sh`
reruns the corrected integer/real probe in both editions; it reports
`RESULT pass=18 fail=0` each time. The run took 0.42 s with peak RSS
16,875,520 bytes.

## Dedupe

The all-state GitHub search `gh issue list -R dsellerbrock/iverilog-uvm
--state all --search 'chandle in:title,body'` returned #759 OPEN and #13
CLOSED among the matching chandle issues. #759 covers only assignment to int;
#13 covers DPI pointer round-tripping. Neither covers the six contexts in
#763/#764. The search output and earlier detailed term searches are under
`attempt-01/` and the `dedupe-extra-*.txt` files.

Standards checked: IEEE 1800-2017/2023 §§6.11–6.14; `$bits` interpretation
in §20.6.2 and bit-stream types in §6.24.3. Chandle restrictions are in
§6.14 (2017 p.106; 2023 p.111).

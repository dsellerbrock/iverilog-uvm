# IEEE 1800 §16.13.4(g) multiclock if-else probe

## Standard basis

IEEE 1800-2017 and 1800-2023 §16.12.6 define an if-else property with
`property_expr` branches. Section 16.13.3 explains clock flow through
multiclocked properties, including branching operators. Section 16.13.4(g)
then gives the exact tested form: an if-else after `a ##1 b`, with a
non-overlapped implication to a `clk1` event in the true branch and a
sequence followed by a `clk2` event in the false branch. The example and
relevant wording are materially the same in both editions.

## Probe and result

- Probe: [`p16_13_4_ifelse_clock_flow.sv`](../../../tests/1800_audit/c16/p16_13_4_ifelse_clock_flow.sv), a minimal executable form of example (g). It keeps `a`, `b`, `d`, `e`, and `f` true and toggles `c` so both branches would be selected if supported.
- Source: current-main toolchain at `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, Icarus 13.0-devel.
- The initial run used `-g2012`; it did not establish whether `-g2017` and `-g2023` work. See the paired-edition correction below.
- Slurm job 3599: one CPU, 1 GiB, five-minute allocation; each compile/simulation command had a 30-second timeout. The source SHA-256 was `f7e8d67996fdc2af956bb742f0887335feb389b2a72b6650677dfc63132cd6cb`.
- Compile exited 3. Icarus reported that `if` accepts only a boolean branch, then reported that the standard-valid sequence/property branches and assertion were dropped. No executable simulation image was produced, so runtime was not reached.
- The robust harness recognized the dropped assertion and returned `PROBE_RESULT=STANDARD_VALID_IF_ELSE_PROPERTY_DROPPED`. Raw output: [`slurm-3599.out`](slurm-3599.out).
- Job 3598 was an initial harness attempt that did not preserve the compile status in its summary. Its raw output is retained as [`slurm-3598-harness-attempt.out`](slurm-3598-harness-attempt.out); job 3599 is the authoritative result.

## Open and closed issue dedupe

On 2026-10-20, separate open and closed GitHub searches across all labels
returned no matches for `16.13.4`, `16.12.6`, `multiclock clock flow`, or
`multiclock if-else property`. `if-else property` returned no open issue and
one closed false positive, #27, about OpenTitan UART runtime stubs. A broader
`multiclock` search found only open #446; a broader `property if` search found
#721 and unrelated property issues. Searches restricted to `1800-audit` for
`multiclock if-else`, `clock flow`, and `property if sequence` found no direct
match.

Nearby issues are not duplicates: open #446 covers variable-length multiclock
antecedents and their handoff/multiplicity semantics; open #721 covers
property conjunction/disjunction under §§16.12.4–.5. Neither covers the
§16.12.6 if-else property branches exercised here.

## Lead status

Probe and dedupe are complete. No issue was filed by the runner; the audit
lead must classify this gap and file it if it agrees it is distinct.

## Paired-edition correction (2026-10-21)

Slurm job 3653 compiled and ran a trivial module with both `-g2017` and
`-g2023` using the pinned `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`
toolchain and `-B .../lib/ivl`; both returned 0. The same property reproducer
was then compiled with both editions and returned 3 with identical dropped-
property diagnostics. The earlier statement that this toolchain lacks these
edition flags was a harness mistake. The paired results and executable hashes
are in [`the corrected probe record`](../../ieee1800-audit-c24-20261021/attempt-03-exit-anon/RESULT.md).

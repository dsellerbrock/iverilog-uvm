# Result — Slurm job 3674

## Outcome

The VPI shared module built; all four designs compiled and ran successfully under the paired editions. Main-design callback behavior matches the expected assertion attempts: one assertion is enumerated as `p39.pa`, both callbacks register, and `COUNTS 2 2` is reported (failures at 5/15 ns; successes at 25/35 ns).

The disable variant fails the expected §39.5.2 behavior in both editions: the standard-value call `vpi_control(620, assertion)` returns 0, logs `Unsupported VPI control operation 620.`, still reports two failures and two successes, and does not disable attempts.

The header also disagrees with Annex M in both editions: `sv_vpi_user.h` defines `vpiAssertion` as 686 and omits `vpiAssertionDisable`, while Annex M gives 744 and 620 respectively. Accordingly, the header's `vpi_iterate(vpiAssertion, NULL)` finds one assertion, while an additional call with the standard numeric type 744 finds zero. The attached `header-constant-check.c` and the full Annex K/M macro comparison also show the `vpiModport` value mismatch and missing assertion callback constants. The C probe defines the standard value 620 only when the header omits it, so it can independently test runtime control dispatch.

All compile and simulation commands exited 0. Main runs have empty stderr. Disable runs have only the simulator's explicit unsupported-control diagnostic in stderr. Assertion failure messages at 5 and 15 ns are expected stimulus and appear in stdout. No `AFTER_FINISH`-style extra output was involved.

## Raw output

Main design, identical under `-g2017` and `-g2023`:

```text
HEADER_MISSING vpiAssertionDisable
HEADER_VPI_ASSERTION 686
ANNEX_ASSERTIONS 0
ASSERT p39.pa
ASSERTIONS 1
CALLBACKS 2
ERROR: ...
       Time: 5  Scope: p39
ERROR: ...
       Time: 15  Scope: p39
COUNTS 2 2
... $finish called at 40 (1ns)
```

Disable variant, identical under `-g2017` and `-g2023`:

```text
HEADER_MISSING vpiAssertionDisable
HEADER_VPI_ASSERTION 686
ANNEX_ASSERTIONS 0
ASSERT p39.pa
ASSERTIONS 1
CALLBACKS 2
DISABLE 0
ERROR: ...
       Time: 5  Scope: p39
ERROR: ...
       Time: 15  Scope: p39
COUNTS 2 2
... $finish called at 40 (1ns)
```

The exact source paths and simulator line-number output are in `slurm-3674-logs/`.

## Reproduction and provenance

- Host: DAN-DESKTOP, Slurm job 3674; submitted 2026-10-21 01:34 MDT; completed 01:34 MDT in 1 second with `ExitCode=0:0`.
- Resources: 1 CPU, 1 GiB requested, 10-minute limit. Per-step timeouts: VPI build 60 s; compile and each simulation 30 s.
- Toolchain: Icarus 13.0-devel, source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; binaries and VPI headers/libraries from `/home/dsell/toolchains/iverilog-fb584a25-20261020/`. The source commit is an ancestor of `origin/main` `10f3a0a2509d0852c2556cb662fb0025121fb2d`.
- Audit checkout HEAD: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; only the two SV inputs and C probe were staged for the job.
- Input hashes: `p39.sv` `6545caa7fa76dd2beb2b9a97597f0d83f67d91d0a35a2eff6d19d6eb5e02c7d4`; `p39_dis.sv` `fa3fde98eb4ecf3d3e493e8d63b7547f808de32d9d86cfda6abf349494af7df6`; `vpi_assert.c` `6ce569a36cbef22fc8ec0828d7eb91039a5867cc2cca95b3dc08af1f48f0a319`.
- Harness: [`run.sbatch`](run.sbatch), SHA-256 `ccca43afc80aafd4209944f573c8806a45e0de2ffa747fb2ac471aecdfdf55f4`.
- The simulator build step succeeded without warnings. The follow-up header check intentionally fails on two Annex M value mismatches and two absent standard macros; its local compiler output and exit code are preserved next to the check source.

## Dedupe and classification

The pre-file open+closed search is in [`DEDUPE.md`](DEDUPE.md). No existing issue matched the assertion API paths or the public-constant discrepancy. Both potential gaps are submitted to the audit lead for classification and issue filing; matrix rows will follow the lead's decision.

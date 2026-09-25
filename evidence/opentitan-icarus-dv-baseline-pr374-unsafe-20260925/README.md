# OpenTitan unsafe DV baseline on the PR #374 Icarus compiler

This is the complete 84-row, one-smoke-per-target OpenTitan matrix on Icarus
`1d2aca7104010839a6c1c358bf9d5d89151923cd` (PR #374 candidate). The
independent, still-open PR #373 is not part of this compiler image. Every
UVM and runtime compile command contains **`-gcommercial-unsafe`**: 84/84,
verified in [provenance.result.json](provenance.result.json). The result is a
**nonstandard compatibility** baseline, separate from strict IEEE reducers.
The pinned OpenTitan checkout `a78922f14a8cc20c7ee569f322a04626f2ac6127`
was clean and unchanged; these matrix rows used no application-source overlay.

| Scope | Status table | Clean matrix passes |
| --- | --- | ---: |
| UVM compile, 35 rows | 8 `DEBT`, 27 `FAIL` | 0/35 |
| Runtime, 49 rows | 8 `DEBT`, 36 compile `FAIL`, 5 `RUNTIME_FAIL` | **0/49** |
| All selected rows | 16 `DEBT`, 63 `FAIL`, 5 `RUNTIME_FAIL`; no timeout | 0/84 |

The conservative qualified matrix DV rate is **0/49**. Eight runtime jobs
completed with exactly one intended pass marker each, zero fail markers, and
zero runtime assertion/error diagnostics, but retained setup and, in three
cases, compiler debt; none is a clean DV pass. The alert, escalation, power,
TL-agent, and crossbar logs show sequence or checked-scoreboard activity.
AON timer and GPIO logs show timer actions and weak-pullup behavior but no
independent transaction count. The TL-agent row also retains an unresolved
coverage-disable option, and the two crossbar rows retain run-mode
orchestration requirements. The [per-row table](results.md)
and [machine-readable results](results.json) preserve every status, exact
command, diagnostic, selected test, and duration. This one-smoke-per-target
matrix is not a denominator for every released OpenTitan named test or seed.
Earlier disposable-overlay OTP and CSRNG named smokes are separate evidence;
they were not rerun or credited on this compiler image.

The aggregate status table is unchanged from the [prior complete unsafe
baseline](../opentitan-icarus-dv-baseline-unsafe-20260925/README.md), but the
PR #374 package fix advances two compile paths. Both EDN rows move from compile
exit 11 with seven hard diagnostics to exit zero with three dropped coverage
bins; the runner still rejects them and starts no EDN runtime. Both OTBN rows
clear their original `otbn_env_cov.sv:2294` type-parse error but expose 233
later hard diagnostics, so OTBN also has no runtime. These are compiler
progress, not DV passes. The exact diagnostics remain in [results.json](results.json)
and the archived logs.

The private installed `ivl` SHA-256 is
`f045786db709fa604990b8de166cfc78c84896acff8850ccbdac3d8eef0978d0`;
the VVP runtime SHA-256 is
`c2373153da12a3992ae2a89b20a0f7c62173c33fc87a03b90065ae347f740665`.
All seven installed compiler components and the UVM 1.2 source-tree hashes
matched at the end of the run. [The provenance record](provenance.result.json)
contains both fingerprints, and [181 archived logs](matrix-logs.tar.gz) have
per-file [SHA-256 values](matrix-log-hashes.json). The runner returned status
1 because debt and failures remain; the report itself completed all 84 rows.

Run from the PR #374 checkout with its private `local-install`:

```sh
OT_PY=/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/python
"$OT_PY" scripts/opentitan_matrix.py \
  --opentitan-root /Users/danielellerbrock/projects/iverilog_uvm/clean-corpora/opentitan-7a3ad34 \
  --build-root /private/tmp/ot-dv-pr374-unsafe-20260925/work \
  --result-json evidence/opentitan-icarus-dv-baseline-pr374-unsafe-20260925/results.json \
  --result-md evidence/opentitan-icarus-dv-baseline-pr374-unsafe-20260925/results.md \
  --iverilog local-install/bin/iverilog \
  --uvm-home /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/third_party/uvm-releases/sources/1.2/uvm-1.2/src \
  --fusesoc /Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/fusesoc \
  --fusesoc-python "$OT_PY" \
  --lane uvm --lane runtime --commercial-unsafe --jobs 4 \
  --setup-timeout 120 --compile-timeout 120 --runtime-timeout 120
```

No Caliptra process, tool, source, or evidence was changed for this baseline.

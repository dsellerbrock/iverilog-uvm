# IEEE 1800 §§6.22.3, 6.22.4, 6.22.6 probe batch

## Scope and standards basis

The paired probes target assignment compatibility, cast compatibility, and
matching nettypes in IEEE 1800-2017/2023 §§6.22.3, 6.22.4, and 6.22.6.
The relevant port connection requirement is §23.3.3 in both editions: when
both sides use user-defined nettypes, the nettypes must match and the net is
merged. The 2017/2023 wording for these tested rules is the same.

## Probe results

Ran on macOS ARM64 under `~/codex-supervisor/localrun`, with a 60-second
timeout on every compiler and simulator invocation. The compiler was built
from audit worktree HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; no
compiler source files were modified. Icarus reports 13.0 devel
`(27f53df24-dirty)`. Compiler SHA-256:
`4cca5dfcfded64ab5aa07255c3f0a3f5dbd8f56b6becdf0288c803f79d5a446c`;
VVP SHA-256:
`2d5e711295134abc6a2553e9cb4215a33f2830e76f1dea5cd188cb991d88b704`.

| Probe | `-g2017` | `-g2023` |
| --- | --- | --- |
| `p06_22c_assignment_compat.sv` — enum-to-integral assignment, truncation, explicit cast to enum | Compiles/runs; `PASS value=2 narrow=3 enum=2` | Same |
| `n06_22b_implicit_integral_to_enum.sv` — implicit integral assignment to enum | Rejects: explicit cast required | Same |
| `p06_22d_matching_nettype_alias.sv` — nettype and its alias connected to a nettype input port | Compiles/runs; `DATA=a`, `DATA=5` | Same |
| `n06_22c_nonmatching_nettypes.sv` — two distinct nettypes with the same `logic [3:0]` data type connected to a nettype input port | **Accepted** | **Accepted** |

The final paired probe run is `localrun-attempt-04.log`; per-case compiler and
runtime logs, versions, and hashes are in `results-attempt-04/`. The run took
1.11 s with peak RSS 16,891,904 bytes. Earlier failed attempts are retained
because they exposed build-path and test-source setup errors; the final source
uses the package import form and passes the matching-alias positive control.

## Issue dedupe

All GitHub searches used `--state all` and are preserved in
[`dedupe-results-full.txt`](dedupe-results-full.txt); the shorter first-pass
search record is [`dedupe-results.txt`](dedupe-results.txt). Searches for clauses 6.22.3,
6.22.4, 6.22.6 and terms covering matching/mismatched/nonmatching nettypes,
nettype ports, aliases, and same-data-type nettypes found no issue directly
covering the observed port-connection acceptance.

- #435 is open and covers class-method resolution functions for user-defined
  nettypes; it does not cover matching at a port connection.
- #474 is closed and covers fixed-array parameter assignment patterns.
- `ivtest/ivltests/sv_interconnect_udnt_conflict_fail.v` covers mismatched
  nettypes on an `interconnect` port, not a user-defined-nettype port.

The open-and-closed GitHub search was refreshed on 2026-10-20 after the live
audit inventory grew to 220 open issues. The exact result is preserved in
[`dedupe-live-20261020.txt`](dedupe-live-20261020.txt). Searches for the
§23.3.3 clause, user-defined nettype ports, matching/nonmatching nettypes,
and identical data types still find no direct match. #435 and #492 remain
related but distinct.

The standards basis was rechecked in IEEE 1800-2017/2023 §23.3.3: when both
port connections use user-defined nettypes, they “shall be of matching
nettypes” and “shall be merged into a single simulated net.” The same-data-
type control does not meet this matching-nettype requirement.

The lead helper returned `daily lead cap reached (80)` despite the supervisor
note reporting 9/80. No issue has been filed and the matrix status remains
pending lead classification; the raw result above is not itself a lead verdict.

At the supervisor's 2026-10-19 21:30 MDT baseline, 89 audit issues were open.
Since then, 96 were created (94 remain open, 2 are closed): §6=40, §10=2,
§11=8, §12=7, §15=1, §20=12, §21=11, §23=5, §25=7, §26=1, §27=2.
The current tracker has 183 open `1800-audit` issues.

## Commands and build records

Run the probes with:

```sh
~/codex-supervisor/localrun 180 env OUT_DIR=evidence/ieee1800-audit-c06j-20261020/results-attempt-04 \
  evidence/ieee1800-audit-c06j-20261020/run-probes.sh
```

Build setup and all localrun logs are preserved here. The final configure
passed explicit Homebrew libffi and Z3 include/library paths; it took 54.87 s
and peaked at 845,856,768 bytes RSS. The total stayed within the local limit
of three build threads and about 7 GiB RSS.

# Fixed OR antecedents with multi-boundary `disable iff`

Issue #447, implementation commit `1479fe3a0bcde94ec9f909933e772ca498fa0449`.

## IEEE scope

The 2017 and 2023 wording is materially the same for the clauses exercised:

- §16.9.7 allows an OR of sequences to produce multiple matches, including
  matches at the same endpoint.
- §16.12 defines asynchronous `disable iff`: a true unsampled disable
  expression disables the property from attempt start through evaluation end,
  and a disabled property neither succeeds nor fails.
- §16.12.7 evaluates a separate consequent for each successful antecedent
  match.
- §§16.13.1 and 16.13.3 cover multiclocked sequence chains and multiclock
  implication.

This change adds one bounded shape: a fixed-length same-clock OR tree as the
antecedent of an implication whose consequent crosses at least two clock-flow
boundaries (three or more clock domains total). Every OR branch has its own
pipeline; each branch match contributes a separate obligation, including
simultaneous matches. An asynchronous disable clears branch pipeline state
and outstanding cross-domain obligations.

Variable-length branches, OR trees containing `and`/`intersect` or other
operators, `first_match`, local variables, match-item calls, branch pass
actions, and two-domain OR antecedents are outside this implementation. The
existing fixed-chain support remains bounded at 64 total antecedent ticks.
Issue #447 stays open for these broader shapes.

The paired positive tests exercise same-endpoint OR matches and asynchronous
reset coincident with a later clock handoff. Boundary tests cover reset at a
handoff edge and cancellation of pending work near end-of-simulation. Paired
negative tests require a clear compile error for an unsupported `and`
antecedent tree. All cases are registered in both the legacy and JSON runners
for `-g2017` and `-g2023`.

## T0 evidence — Mac

Host: macOS 27.0, ARM64. Source commit:
`1479fe3a0bcde94ec9f909933e772ca498fa0449`. Build used Homebrew Bison 3.8.2
and Homebrew libffi/Z3 include and library paths, followed by `make -j3`
(20.31 s, peak RSS about 1.01 GiB) and `make install` into the ignored
`local-install/` prefix.

Focused checks passed before the smoke run:

| Check | Result | Wall time |
|---|---:|---:|
| Legacy fixed-multiclock-control list, including the new cases | 28/28 | 5.29 s |
| JSON/VVP fixed-multiclock-control list, including the new cases | 28/28 | 1.80 s |

```sh
PATH=../local-install/bin:$PATH perl vvp_reg.pl regress-sv_assert_multiclock_fixed_control-focus-legacy.list
PATH=../local-install/bin:$PATH python3 vvp_reg.py regress-sv_assert_multiclock_fixed_control-focus-vvp.list
```

Smoke command:

```sh
~/codex-supervisor/localrun 3600 env \
  PATH=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue447-disable-iff/local-install/bin:$PATH \
  ./ci/run-smoke.sh
```

Exit 0; 175.26 s wall time; peak RSS 116,654,080 bytes. Results: compiler/VVP
56/56, VPI 131/131, negative suite 152/152, plus every reproducer and runtime
invariant in the smoke script. Full output is in
[t0-smoke.log.gz](t0-smoke.log.gz).

## T1 evidence — Slurm

First attempt, job 1240, was OOM-killed while compiling `elaborate.o`
(`elaborate.cc`) with three CPUs and 2 GiB RAM, before any test ran. The exact
Slurm output and build log are preserved as
[t1-attempt-1240.out.gz](t1-attempt-1240.out.gz) and
[t1-attempt-1240-build.log.gz](t1-attempt-1240-build.log.gz); this is a
resource failure, not a test result.

Retry job 1241 completed on `DAN-DESKTOP` with exit code 0 in 2m19s, using
three CPUs and 4 GiB RAM. The graph-selected tests passed:

| Check | Result |
|---|---:|
| Fixed multiclock-control legacy list | 28/28 |
| Fixed multiclock-control JSON/VVP list | 28/28 |
| Implication-tree legacy list | 1/1 |
| Implication-tree JSON/VVP list | 2/2 |
| `tests/sva_nfa/run.sh` | 65/65 |

The SVA NFA runner exercises neighboring assertion tree/combinator lowering;
each compiler and simulator process ran under a 120-second GNU `timeout`.
All Slurm output and build/test logs are preserved in
[t1-job-1241](t1-job-1241/). Slurm did not retain a post-completion MaxRSS
value. The first run's OOM at 2 GiB and the retry's successful 4 GiB build
show that 4 GiB was sufficient for this build; they do not indicate a code
test failure.

## T2

Not run. This PR must join the next batch gate before merge.

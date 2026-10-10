# IEEE 1800 wide scalar `randc` domain cap (#420)

## Scope and standard

IEEE 1800-2017 and 1800-2023 §18.4.2 define `randc` as a random permutation
without repetition within a cycle. Both editions permit an implementation
size limit with a minimum of 8 bits. Section 18.6.3 requires failed
randomization to preserve random-variable values. The local PDFs used were
`/Users/danielellerbrock/Documents/Standards/1800-2017.pdf` and
`/Users/danielellerbrock/Documents/Standards/1800-2023.pdf`.

This is a bounded implementation extension, not a claim that the standard
requires every wide or aggregate `randc` shape. The eligible non-static direct
scalar subset wider than the existing 20-bit dense-history limit can now use
an exactly enumerated feasible set of up to 2,048 values. Static, array,
aggregate and container forms remain outside this change. Requests above the
cap still fail closed.

## Baseline and implementation

Fresh `origin/main` at `c339b9f2287a743aeb7ab6de6528e8d34a4dd602` reproduced
the failure: a 21-bit non-static scalar constrained to `[0:1024]` compiled in
both editions and failed its first `randomize()` with `wide randc feasible
domain is not exactly enumerable`.

The 1,024-value ceiling was enforced in two places: the sparse exact-domain
enumeration and the scalar randc history/transaction gates. All three now use
one 2,048-value cap. The general enumeration cap, dense history width, and
container history cap remain unchanged. Over-cap scalar randc inputs preserve
the explicit failure path.

## Evidence

- `make install` completed from the feature checkout into its repository-local
  `local-install` prefix.
- Focused legacy and JSON/VVP lists each passed 4/4 in normal mode and 4/4
  with `--strict`. Each list includes both IEEE editions, the 1,025-value
  sparse scalar case, and the existing global-randc neighbors.
- The paired permanent test checks 64 no-repeat draws, failed-call value
  rollback, and rejection of a 2,049-value domain.
- The standalone [`standalone-full-cycle.sv`](standalone-full-cycle.sv) sweep
  completed all 1,025 values without repetition and verified the next draw
  starts a new cycle under both `-g2017` and `-g2023`.
- `scripts/slurm-randc-cycle.sh <branch>` stages a clean branch commit and
  runs this full-cycle source on Slurm, with build products and extracted
  tool dependencies isolated under the run directory. Draft PR
  [#529](https://github.com/dsellerbrock/iverilog-uvm/pull/529) includes
  tested source commit `445c2ebff69c112c4a452f3115bca9a9c8cfec36`. Job 12 has been
  submitted for commit `445c2ebff69c112c4a452f3115bca9a9c8cfec36`; it is
  queued and has no result yet. Its log is at
  `/home/dsell/slurm-runs/iverilog-uvm/codex-420/20261010T001427Z-445c2ebf-91322/logs/randc-cycle-20261010T001427Z-445c2ebf-91322-12.out`.
- CI was not queried, per the campaign instruction. Exact-head CI
  qualification remains pending.

The feature is limited to this direct scalar shape and cap. No full suite,
CI, or wider/aggregate randc qualification is claimed.

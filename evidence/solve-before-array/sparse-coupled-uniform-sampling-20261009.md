# Sparse coupled legal-tuple sampling (#416) — 2026-10-09

## Standard and baseline

The local IEEE 1800-2017 text confirms §18.5.10's requirement that legal
value combinations have equal probability; the local IEEE 1800-2023 PDF has
the corresponding requirement in §18.5.9. The local 2017 errata has no
correction to §18.5.10. The references used were the workspace's extracted
`../evidence/ieee-1800-local-reference-20260923/1800-2017.txt`,
`../reference-standards/local/IEEE_Std_1800-2023.pdf`, and
`../reference-standards/local/IEEE_Std_1800-2017_errata.pdf`. These personal
reference files are not included in this repository.

Issue #416 was OPEN when selected on refreshed `origin/main`
`c339b9f2287a743aeb7ab6de6528e8d34a4dd602`. That source proposed uniform
full-bit-vector tuples for 4,096 attempts, then left an exhausted component
unpinned for the existing non-uniform solver fallback.

The paired reducer has three complete tuples:

| `mode` | `value` | Count required by uniform tuple sampling |
| --- | ---: | ---: |
| 0 | 0 | 40 of 120 |
| 1 | 0 | 40 of 120 |
| 1 | 1 | 40 of 120 |

The branches contain different numbers of tuples, so uniformity over the
`mode` bit alone would not satisfy the standard. On refreshed main, direct
2017 and 2023 probes with seed 416 both produced `64,26,30`; the first bin
exceeded the registered 22–58 bound.

## Change and boundary

After 64 rejected proposals, the existing joint sampler now exactly enumerates
eligible connected direct-scalar components when every variable is at most 64
bits and there are no pending soft constraints. If the complete set contains
at most 4,096 tuples, one tuple is selected with unbiased `uniform_index()` on
an existing property-owned RNG stream, and all component variables are pinned
in both the hard solver and optimizer. Dense components retain rejection
sampling. Unknown enumeration results fail explicitly.

More than 4,096 tuples, widths above 64 bits, soft constraints, and array or
member components remain outside this exact enumeration path. An over-cap
4,097-tuple boundary case confirms the existing fallback still returns a
legal value; it does not qualify that fallback as uniform. Broader clause 18
remains PARTIAL.

## Local validation

- `make -j1 YACC=/opt/homebrew/opt/bison/bin/bison LEX=/usr/bin/flex` and
  `make install` passed on the refreshed branch.
- Paired sparse positive, unsatisfiable rollback, and over-cap cases passed
  2/2 in the legacy runner and 2/2 in JSON/VVP.
- Adjacent `sv_randomize_global_sampling_fail` controls passed 2/2 in each
  runner.
- No CI status was checked. This is local evidence only; it does not qualify
  the change on other platforms or close the broader uniformity requirement.

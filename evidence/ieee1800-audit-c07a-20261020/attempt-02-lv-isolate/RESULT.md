# §7.10 l-value isolation and runtime control (Slurm job 3510)

- Host: DAN-DESKTOP; 1 CPU, 1 GiB; each compile/run had a 30-second timeout.
- Compiler: Icarus 13.0-devel `cc25756d1`; `iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Both editions were run. Exact two-line change in the full control source is `queue-size-only.diff`; full source/test hashes are in `results/SHA256SUMS`.

## Isolated l-value forms

| Case | Statement | 2017 | 2023 | Output where it ran |
|---|---|---|---|---|
| lv1 | `q[$+1] = 50` | compile rc 2 | compile rc 2 | — |
| lv2 | `q[$] = 9` | pass | pass | `9` |
| lv3 | `q[$-1] = 8` | pass | pass | `8` |
| lv4 | `q[q.size()] = 50` | pass | pass | `3 50` |
| lv5 | bounded `b[$+1] = 6` | compile rc 2 | compile rc 2 | — |

Both failed cases report `syntax error` and `Syntax in assignment statement l-value` at the assignment. This isolates the parser failure to `$+1` queue l-value expressions; `$` alone, `$-1`, and the `size()` append control work.

## Full runtime control

The modified full probe compiles and runs in both editions. Every listed data value matches the lead's expected table except `P4`: actual output is `P4 0 x`, while the table supplied for this run expected `P4 0 0`.

IEEE 1800-2017 §7.4.6 Table 7-1 (p.149) and IEEE 1800-2023 §7.4.5 Table 7-1 (p.156) say a nonexistent entry of a 4-state integral type returns `'X`; `int` is 4-state. Therefore `P4 0 x` is the standard-consistent empty `pop_front()` result, and the expected `0` needs correction. The full probe's other invalid-read check reports `R1 0` for `q[7]`; by the same table that appears inconsistent with the required `'X` and needs an isolated confirmation before issue classification. Queue write legality/warnings are specified in §7.10.1; bounded queue overflow is specified in §7.10.5.

## Warning lines

The following seven warning lines were emitted verbatim in **each** edition, in this order (the two editions' warning sets are identical):

### `-g2017`

```text
Warning: assigning to queue<vector>[9] is outside of size (5). 32'b00000000000000000000000001100011 was not added.
Warning: inserting to queue<vector[32]>[9] is outside of size (6). 32'b00000000000000000000000001001101 was not added.
Warning: cannot insert at a negative queue<vector[32]> index (-1). 32'b00000000000000000000000001001101 was not added.
Warning: skipping out of range delete(42) on queue of size 6.
Warning: pop_front() on empty queue<vector[32]>.
Warning: push_back(32'b00000000000000000000000000000101) skipped for already full bounded queue<vector[32]> [4].
Warning: assigning to queue<vector>[4] is outside bound (4). 32'b00000000000000000000000000000110 was not added.
```

### `-g2023`

```text
Warning: assigning to queue<vector>[9] is outside of size (5). 32'b00000000000000000000000001100011 was not added.
Warning: inserting to queue<vector[32]>[9] is outside of size (6). 32'b00000000000000000000000001001101 was not added.
Warning: cannot insert at a negative queue<vector[32]> index (-1). 32'b00000000000000000000000001001101 was not added.
Warning: skipping out of range delete(42) on queue of size 6.
Warning: pop_front() on empty queue<vector[32]>.
Warning: push_back(32'b00000000000000000000000000000101) skipped for already full bounded queue<vector[32]> [4].
Warning: assigning to queue<vector>[4] is outside bound (4). 32'b00000000000000000000000000000110 was not added.
```

The required warning for the invalid write W2 appears first. The insert/delete/empty-pop warnings are permitted by their clauses. The two bounded-queue writes produce warnings, as specified by §7.10.5.

Dedupe for this queue tranche: all six lead-specified terms were searched in both open and closed issues; all returned no hits (`dedupe-open-closed.txt`). No issue was filed pending an isolated invalid-read check and lead classification.

Raw outputs: `results-3510.tar.gz`; source archive: `input.tar.gz`; full compiler, stdout, stderr, warning, timing and hash data are preserved in `results/` and `logs/`.

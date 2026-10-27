# §7.10.2.4/.5 empty queue pop defaults (Slurm job 3511)

- Host: DAN-DESKTOP; 1 CPU, 1 GiB; each compile/run had a 30-second timeout.
- Toolchain: Icarus 13.0-devel `cc25756d1`; `iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Both editions compile and run successfully (compile and run rc 0). Raw stdout is identical:

```text
PI x x 0
PB x x 0
PL x x x
PG x x x
PR 0.0 0.0 0.0
PS '' '' ''
PK 1 1 1
```

For the two-state `int` and `bit[7:0]` queues, `pop_front()` and `pop_back()` return `x`, but an invalid `[3]` read of the same empty queue returns `0`. IEEE 1800-2017 §7.10.2.4/.5 says empty pops return the same value as reading a nonexistent element; the 2-state type row in §7.4.6 Table 7-1 (2017 p.149) gives `'0`. IEEE 1800-2023 uses §7.4.5 Table 7-1 (p.156). The remaining element types agree with their invalid-read values.

## Warning lines

Warnings are permitted for empty pops. These 14 exact warning lines were emitted for **each** edition:

### `-g2017`

```text
Warning: pop_front() on empty queue<vector[32]>.
Warning: pop_back() on empty queue<vector[32]>.
Warning: pop_front() on empty queue<vector[8]>.
Warning: pop_back() on empty queue<vector[8]>.
Warning: pop_front() on empty queue<vector[8]>.
Warning: pop_back() on empty queue<vector[8]>.
Warning: pop_front() on empty queue<vector[32]>.
Warning: pop_back() on empty queue<vector[32]>.
Warning: pop_front() on empty queue<real>.
Warning: pop_back() on empty queue<real>.
Warning: pop_front() on empty queue<string>.
Warning: pop_back() on empty queue<string>.
Warning: pop_front() on empty queue<object>.
Warning: pop_back() on empty queue<object>.
```

### `-g2023`

```text
Warning: pop_front() on empty queue<vector[32]>.
Warning: pop_back() on empty queue<vector[32]>.
Warning: pop_front() on empty queue<vector[8]>.
Warning: pop_back() on empty queue<vector[8]>.
Warning: pop_front() on empty queue<vector[8]>.
Warning: pop_back() on empty queue<vector[8]>.
Warning: pop_front() on empty queue<vector[32]>.
Warning: pop_back() on empty queue<vector[32]>.
Warning: pop_front() on empty queue<real>.
Warning: pop_back() on empty queue<real>.
Warning: pop_front() on empty queue<string>.
Warning: pop_back() on empty queue<string>.
Warning: pop_front() on empty queue<object>.
Warning: pop_back() on empty queue<object>.
```

No warning is required for these operations. Dedupe queries were run in open and closed states; #849 is the separate `$+1` l-value gap, #27 is unrelated OpenTitan runtime work, and #486 is an associative-array warning issue (§7.8.6), not queue pop values. Details are in `dedupe-open-closed.txt`.

Raw results: `results-3511.tar.gz`; source/tool hashes: `results/SHA256SUMS`; outputs and stderr are preserved under `results/logs/`.

# §7.12.4 iterator index and §7.12.5 map results

- Simulator source commit: `cc25756d187314742d347267c2a513b3e640a7fb`
- Slurm job: `3519` (`1` CPU, `1G` memory, five-minute limit; completed)
- Toolchain: Icarus Verilog 13.0-devel (`cc25756d1`); `iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`, `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`
- Per-command timeout: 30 seconds, TERM then KILL after 2 seconds.

## `map()`

`p07_12_5_map.sv` compiled and ran under `-g2023` with exit code 0 and empty stderr. Output matched all expected values:

```text
M1 2 3 4
M2 4 6 9
M3 1 1 0 1
M4 2 10 20
M5 3 5 8
```

Under `-g2017`, compilation returned 5 and rejected all five calls with “the array map() method requires IEEE1800-2023; compile with -g2023 (or -glatest).” This edition distinction is correct.

## Optional iterator-index argument

`p07_12_4_iterarg.sv` uses the 2023 standard example's renamed iterator index on a queue of structs with a member named `index`. Under `-g2023`, compilation fails with `Object ... arr has no method "find(...)"`. Under `-g2017`, compilation correctly rejects this 2023-only second argument (“the array method index argument requires IEEE1800-2023”).

The no-second-argument control in [`attempt-02-index-control/RESULT.md`](../attempt-02-index-control/RESULT.md) compiles and runs in both editions, printing `C1 2 20`. Thus the 2023 failure is specific to the optional index argument.

The standards text and edition distinction are documented in [`STANDARD.md`](STANDARD.md). The open/closed issue search and review are documented in [`DEDUPE.md`](DEDUPE.md). Raw compiler and runtime output is under [`results/`](results/), with scheduler output in [`slurm-3519.out`](slurm-3519.out).

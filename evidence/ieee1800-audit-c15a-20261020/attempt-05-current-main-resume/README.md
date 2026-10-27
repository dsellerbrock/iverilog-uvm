# Clause 15.4 current-main confirmation

- Host: macOS localrun; source: clean `origin/main` at `c41e504c7ee64a7bfc047f8662d3bc8044f1d90f`.
- Command: `~/codex-supervisor/localrun 900 bash evidence/ieee1800-audit-c15a-20261020/attempt-05-current-main-resume/run-local-retry-z3.sh`
- Result: localrun exit 0; 50.44 s; peak RSS 846,479,360 bytes.
- Toolchain: see `toolchain.sha256` (`iverilog` 819b5399129e9bf686e16f779f0e112c74a8cc7f72dbd3c2da51f2e6817da27c; `vvp` 6f8ddbad61207e31af6ac778f2424e62175b31950df040d098476a356ce6981d).
- Both `-g2017` and `-g2023`: positive mailbox probe passed 16/16; waiter assignment passed with `w1=100 w2=200 w3=300`; parameterized `put(int)` and `get(int)` mismatches were rejected at compile time.
- Both editions: blocking `get` with a mismatched message compiled and ran without a diagnostic, printing `SURVIVED 0`.
- Build retries caused by missing Homebrew `ffi.h` and `z3.h` are recorded in `logs/`; the successful retry supplied the dependency include and library paths.

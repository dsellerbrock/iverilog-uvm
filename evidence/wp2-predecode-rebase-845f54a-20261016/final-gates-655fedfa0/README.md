# Final post-rebase correctness gates

The campaign measurement pin is `c7ebca768c21c251d9c165c9aff0e363768030b1`.
The once-rebased comparison base is
`845f54a5724c4d2af13dde40eca6d290c80c41d9`; this run tests candidate source
commit `655fedfa06b0e2018183e280d3e8a3142c525b32`, with `uvm-core` at
`78c06547a2a0a29b3dc9dcafae62b75b2ff61544`.

Slurm job 1497 runs `make check`, the full `.github/ivtest_gate.sh` suite
(including `vvp_reg.py` JSON tests), and the real-DPI UVM regression. It uses
4 CPUs, 8 GiB, and a four-hour limit. The cluster had 10 idle CPUs and no
active A5 job when it was submitted.

Source archive checksums:

| Input | SHA-256 |
| --- | --- |
| Reference from `845f54a` | `4f1d8c47e7ccd94f28d084be5f7e34f09a871795a8e646a77275079f51fb6b59` |
| Candidate `655fedfa` | `46e96b85d3aad9bce898f978e278e8e7d0178fffa02c50b76a9fd4683806bf5a` |
| `uvm-core` | `47edabcda41a463532346d45b5479a7e3101202e620af762fc203467526e3845` |

Result: PASS, Slurm exit 0. `make check`, both base and candidate builds and
installs (including FPGA target installs), the full ivtest gate, and UVM all
passed. The gate reported 7,436 legacy cases (7,431 passed, 0 failed, 2 not
implemented, 3 expected failures), VPI 131/131, negative tests 152/152,
runtime invariants 15/15, focused indexed-slice tests 16/16, JSON 4,675/4,675,
and real-DPI UVM 367/0/0. The archive checksum verification passed before the
run. Detailed commands, per-gate status, resource use, and logs are under
`run-1497/`. The exact-head cross-platform `test.yml` remains the final gate;
its status is tracked on PR #599.

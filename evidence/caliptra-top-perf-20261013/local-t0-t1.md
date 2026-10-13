# Local T0/T1 validation

Host: macOS 27.0, arm64. Local compiler: Icarus Verilog 13.0 (devel).
Compiler SHA-256: `00e7b3084f15879fadfad71dadd927bdcfec61ef766ca9faaf64d4ee7508c657`.
VVP SHA-256: `501bfc7039212694f654ac916cc6f67b9b6d5f6f5e4add903db7a6c3561c751e`.

| Tier | Command / selected list | Result | Wall time | Peak RSS |
|---|---|---:|---:|---:|
| T0 smoke | `~/codex-supervisor/localrun 1200 env PATH="/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue-536/local-install/bin:$PATH" IVERILOG=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue-536/local-install/bin/iverilog VVP=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue-536/local-install/bin/vvp IVPI=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue-536/local-install/bin/iverilog-vpi CC=/tmp/a3-536-cc-wrapper.sh ci/run-smoke.sh` | exit 0; compiler/VVP 56/56, VPI 131/131, negative 149/149; DPI protocol passed | 147.42 s | 114,950,144 B |
| T1 legacy | from `ivtest/`: `~/codex-supervisor/localrun 900 env PATH="/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue-536/local-install/bin:$PATH" perl ./vvp_reg.pl regress-opentitan-array-of-containers-focus-legacy.list` | exit 0; 18/18 passed | 3.11 s | 16,957,440 B |
| T1 JSON/VVP | from `ivtest/`, each of the 18 names in `regress-opentitan-array-of-containers-focus-vvp.list` run separately with `~/codex-supervisor/localrun 120 env PATH="/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue-536/local-install/bin:$PATH" python3 ../scripts/run_with_timeout.py 60 -- python3 ./vvp_reg.py /tmp/a3-536-t1-<test-name>.list` | exit 0 for every case; 18/18 passed | 4.03 s total | 21,823,488 B max |

The JSON golds now include the existing IEEE 1800-2017/2023 7.8.6 missing-entry warnings emitted by three neighboring tests. The scalar-index JSON gold also reflects the added signed and unsigned 64-bit boundary cases.

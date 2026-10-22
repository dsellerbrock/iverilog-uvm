# IEEE 1800 §19.5.7 value-resolution probe

**Standard:** IEEE 1800-2017 §19.5.7, pp. 568–569; IEEE 1800-2023 §19.5.7. The effective type determines value representability. The standard requires warnings for negative signed values cast to unsigned, values not preserved by the effective-type cast, and X/Z bin values. Warned singleton values are excluded; partially representable ranges are intersected with the effective-type domain; ranges with no representable values are excluded.

**Probe:** tests/1800_audit/c19/p19_05_7_resolution.sv makes the standard p1/p2 cases observable using target and control bins. Each compile/runtime process had a 30-second timeout.

**Environment:** Slurm host DAN-DESKTOP; job 3418; 1 CPU, 1 GiB, 10-minute limit. Pinned toolchain is current-main Icarus 13.0-devel cc25756d1 under /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/. The executable hashes and input/harness hashes are in SHA256SUMS.

**Commands:** for each edition 2017 and 2023, compile iverilog -g<edition> -o <image> input/p19_05_7_resolution.sv, then run vvp <image>, both wrapped by input/run_with_timeout.py 30 -- ... .

**Results:** both editions compile and run with exit code 0. Coverage is exactly A=100.0, C=50.0, D=50.0, E=50.0, F=100.0, matching the lead's expected results. The compiler emits five warnings per edition, at source lines 4–8; complete raw logs are retained in logs/.

The exact warnings are:

- unsigned (lines 4, 5, 6): warning: covergroup bin 't' has a value outside its effective unsigned 3-bit coverpoint type; the affected range is intersected with that type's domain.
- signed (lines 7, 8): warning: covergroup bin 't' has a value outside its effective signed 3-bit coverpoint type; the affected range is intersected with that type's domain.

The five warnings correspond to the out-of-range elements identified by the standard example. The coverage outcomes confirm partial range intersection and exclusion of entirely invalid values.

**Dedupe:** searches included open and closed issues. The post-probe recheck found no overlap: see dedupe-open-closed.txt. Open §19 issue titles #622–#628, #630, #659, #685–#689, and #696 were reviewed; none describes §19.5.7 value casting or range intersection.

# IEEE 1800 §18.16 randcase probe

**Standard:** IEEE 1800-2017 §18.16, pp. 543–544; IEEE 1800-2023 §18.16, p. 564. The clauses specify weighted selection, zero-weight behavior, arbitrary integral weight expressions, unsigned addition at the maximum weight precision, and at-most-once evaluation of each expression.

**Probe:** input/p18_16_randcase.sv checks the standard 3:1:4 distribution, individual zero weight, all-zero weights, mixed-width expression weights, and single evaluation of side-effecting weight expressions. Each compile and runtime process used a 30-second timeout.

**Environment:** Slurm host DAN-DESKTOP; job 3399; 1 CPU, 1 GiB, 10-minute limit. Pinned toolchain is current-main Icarus 13.0-devel cc25756d1 under /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/. iverilog SHA-256 1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593; vvp SHA-256 e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb. Input and harness hashes are in SHA256SUMS.

**Commands:** for each edition 2017 and 2023, compile iverilog -g<edition> -o <image> input/p18_16_randcase.sv, then run vvp <image>, both wrapped by input/run_with_timeout.py 30 -- ... .

**Results:** both editions compile and run with exit code 0 and RESULT pass=5 fail=0. The 800-call distribution is 307/100/393 for 3:1:4. The mixed-width case selected one of the two small-weight branches once in 100 calls (hit=1); this observation is reported, not gated. The zero-weight branch was never selected, the all-zero case took no branch, and each side-effecting expression was evaluated once. No diagnostic was emitted for the all-zero case (a warning is permitted).

**Dedupe:** post-probe open-and-closed searches for randcase and random weighted case returned no matches; see dedupe-open-closed.txt. No issue has been filed pending lead classification.

**Earlier attempts:** job 3397 failed before compilation due to input staging layout and is recorded in ../attempt-01-randcase/README.md; it is not test evidence. Job 3398 passed the same assertions but omitted the requested hit print; job 3399 is the complete recorded result.

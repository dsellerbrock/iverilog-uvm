# WP0 post-rebase remeasurement

## Revisions

| Role | Revision |
| --- | --- |
| Campaign pinned base | `f9f8e0a79f230f38da6cbb4445994ad1075ad531` |
| Deliberate post-rebase measurement base | `7f35ca38c86723ab40e6ebfe9fd77259827e23f9` |
| WP0 runtime change | `65844b33e5bcc31e3cd2bdc56ea942b14ab9b975` |
| Rebased candidate source | `1174ea06ac5e3a926b1fa1c1bd3449a396507272` |
| UVM core submodule | `78c06547a2a0a29b3dc9dcafae62b75b2ff61544` |

The original campaign measurements used the campaign-pinned base. The one
pre-merge rebase brought in changes to `vpi/` and `vvp/`, including
`vvp/vthread.cc`, so this directory records the one allowed follow-up on the
new base. The revised campaign stopped further wall-time calibration; the
five-pair medians in the main evidence remain the pinned-base final table.
One deterministic Callgrind A/B ran on this base after correctness gates to
retain disabled-build hot-path identity evidence. No further rebase or
wall-time calibration is part of this work.

The exact path diff is in `origin-main-runtime-diff.txt`. Job 1150 passed all
stages through the JSON/VVP regression (4,651 tests, 16 baseline failures,
zero delta) but invoked UVM from the wrong directory. Follow-up job 1181 ran
from the candidate source root and passed UVM 367/0/0 with real DPI. Callgrind
job 1182 completed with identical selected hot-path counts, byte-identical
output, and +274 whole-process instructions (+0.000000290%). Its profiling
stage passed; the wrapper exited 1 only because its final checksum command
included a results subdirectory. The recorded profile hashes were verified
after decompression. Exact-head Linux and Windows CI remain required before
merge.
Source archives, gate scripts, logs, and instruction-count evidence are
recorded in the subdirectories here.

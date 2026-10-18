# WP6 post-rebase measurements

Measurement base: `d9caaaea5b410ed14e7ca14be828fc2f2c9fea44`.
Candidate source commit: `498bf0826b810d5fe8ae560b02903c7bb5558c36`.

This deliberate remeasurement follows the single pre-merge rebase. The required
`ca559..origin/main` runtime-path diff touched only `vvp/vthread.cc` (48 lines
from #640), so the original pinned-base result remains recorded separately at
[`wp6-vpi-fastpath-ca559-20261018`](../wp6-vpi-fastpath-ca559-20261018/README.md)
and is not substituted for this new-base evidence.

The candidate patch contains only `vvp/vpi_priv.cc` and `vvp/vpi_tasks.cc`;
its SHA-256 and the exact base/submodule archive hashes are in
[`input/source-inputs.sha256`](input/source-inputs.sha256). The compressed
source snapshot excludes only documentation, evidence, and `.ai` metadata; it
includes the runtime, benchmark corpus, test suites, and three pinned UVM
submodules.

Build attempt 2617 stopped before compilation because the shared Slurm Git
cache could not transition cleanly from `ca559fd` across #640; the preserved
failure record is [here](attempts/build-2617/FAILURE.md). Archive-based build
job 2618 succeeded for both the `d9caaaea` reference and the VPI candidate.
Its binary hashes and complete logs are in
[`attempts/build-2618`](attempts/build-2618/).

The new-base Callgrind screen, full correctness gate, and isolated three-run
wall measurement are still pending.

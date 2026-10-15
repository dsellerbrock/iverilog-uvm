# Fused X/Z and overflow word scan

Pinned measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

This follow-up to the word-plane converter candidate folds X/Z rejection
into the same A-plane word walk used for sign extension and overflow checks.
The focused 100,000-access workload also checks an X bit at index 100 and a
Z bit at index 64. A separate wide-index regression covers signed and
unsigned overflow, sign extension, and X/Z selection. The pinned reference
build and the candidate patch are built/measured as an A/B pair.

Slurm job 1371 passed with 2 CPUs, 8 GiB, and a 2-hour limit. Focused process
instructions were 2,342,144,538 → 1,861,170,476 (−20.535627%), versus
−20.446443% for the prior word-plane run. The focused A/B is matched; that
cross-run comparison is not exact because this input adds a Z-index assertion
absent from the earlier input. Both focused and wide-index regression outputs
matched byte-for-byte, including the negative wide index and X/Z cases. The PR
keeps this report, the focused instruction row, workload source, and patch
hashes; raw profiles, logs, and generated outputs remain in the local evidence
archive. The candidate and prior word-plane patch SHA-256 values are in
`SHA256SUMS`.

The full 18-workload re-screen subsequently passed on this same pinned base;
see [`fusedxz-broad-20261015/`](../fusedxz-broad-20261015/README.md). The
dedicated wide/narrow X/Z edge test also passed on both installs; see
[`fusedxz-edge-65/`](../fusedxz-edge-65/README.md).

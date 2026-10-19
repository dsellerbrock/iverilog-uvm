# WP6 thread vec4 stack move screen

Pinned measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.

The current-main Caliptra profiles attribute 3.03–3.39% of sampled time to
`vvp_vector4_t::copy_from_big_` and about 3% to allocation. This prototype adds
move construction/assignment for `vvp_vector4_t`, moves the thread stack top on
pop, and moves temporary values on push. It preserves the two bit planes and
the existing stack order.

The target screen is `wide_vectors`, where the corpus profile assigns 31.23%
of samples to vector multiplication. A single interleaved Callgrind pair on the
pinned base must reduce target instructions by at least 10%, keep every other
workload within +2%, and preserve all 18 outputs byte-for-byte. This prototype
makes no Caliptra throughput claim until measured.

Attempt r1 (job 2904) was cancelled during the clean reference build after
review found that the moved-from vector's scalar words also need clearing to
keep it safely reusable. It produced no candidate build or performance result;
the frozen input and partial logs are under
[`attempts/r1-superseded/`](attempts/r1-superseded/). The Slurm `EXIT` trap
recorded exit code 0 on cancellation, so that marker is not treated as success;
the job output confirms the signal. Attempt r2 adds the reset and corrected
signal handling and is pending on the pinned base.

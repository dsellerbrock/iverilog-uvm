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
workload within +2%, and preserve all 18 outputs byte-for-byte. Build and
screen results will be recorded here; this prototype makes no Caliptra
throughput claim until measured.

# Sparse wide multiply, current-main remeasurement

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.

The current-main c344 profile attributes 38.44% of `wide_vectors` samples to
`vvp_vector4_t::mul`. The candidate trims zero high limbs after the existing
complete X/Z scan, then limits result allocation and partial-product loops to
the remaining limbs. Its earlier Callgrind screens improved `wide_vectors`
by 40.53% with byte-identical outputs across all 18 workloads; no Caliptra
gain is claimed.

The runtime-path diff from the earlier `ca559fd` screen to this pinned base
touches VVP files, so this run deliberately rebuilds and remeasures the same
patch on `c344d201`. It does not change the earlier evidence or rebase a PR.
The candidate patch, semantic fixture, and Slurm scripts are under `input/`,
`semantic/`, and `submit/`. The reference build is a read-only hard-linked
copy of the successful c344 reference install used for WP6; candidate build
and Callgrind outputs have separate directories.

Slurm build job 2751 passed on c344 and the sparse multiply equivalence
fixture matched the read-only reference. Array job 2752 passed all three
groups: all 18 outputs match; `wide_vectors` fell 40.528366% (6,538,341,258
to 3,888,458,364 instructions); the largest other increase rounds to
0.000000%. The Caliptra c344 profiles sample `vvp_vector4_t::mul` at only
1.51–1.53% in these three firmware windows. This is a WP4 interpreter
follow-up, outside the requested WP5–WP13 sequence, and does not establish a
material Caliptra throughput gain; retain it as a screened result without
opening an M3 PR. Results are under
[`attempts/job-2752/`](attempts/job-2752/).

# §18.5.5 / §18.5.4 uniqueness slices

IEEE 1800-2017 §18.5.5 (pp. 513–514) permits an integral-leaf unpacked array “or a slice of such a variable” as a `unique` group member. IEEE 1800-2023 §18.5.4 (p. 534) retains slices and also permits real-leaf arrays. The standard's example includes `unique {b, a[2:3], excluded};`.

U1–U4 probe slice-only, reversed-range, non-constant-bound, and mixed scalar/slice groups. U5 is the whole-array control. Each randomization must preserve pairwise uniqueness among the selected elements.

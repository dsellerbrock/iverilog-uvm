# Disposable Apple M5 VVP GPU copy probe (2026-09-24)

The mailbox VVP sample has `vvp_vector4_t::copy_from_big_` in the
`of_LOAD_VEC4` path. Current source allocates two contiguous `unsigned long`
planes and copies each plane; the `a/b` pairs encode 0/1/X/Z. This probe copies
the same two-plane bytes with a Metal compute kernel and with CPU `memcpy`.

```
cd evidence/caliptra-l0-gpu-copy-probe-20260924
xcrun swiftc -O gpu_copy.swift -o gpu_copy
./gpu_copy > results.txt
./gpu_copy > results_repeat1.txt
./gpu_copy > results_repeat2.txt
```

Measured on Apple M5 (10 GPU cores, Metal 4). Times are nanoseconds per
operation. Each GPU timing includes command creation, encoding, dispatch,
submission, and synchronous completion. Shader compilation, buffer allocation,
and any VVP-to-Metal packing are excluded, which favors the GPU. CPU vector
timing calls `memcpy` once per vector; CPU flat timing copies the full batch
once. All output bytes were compared with the input, including arbitrary X/Z
bit-plane patterns. The three raw runs are alongside this file.

| Shape | CPU vector median | GPU median | GPU / CPU vector |
| --- | ---: | ---: | ---: |
| one 16-byte vector | 49 ns | 397,799 ns | 8,118x |
| one 128-byte vector | 26 ns | 297,792 ns | 11,454x |
| one 1-KiB vector | 35 ns | 300,655 ns | 8,590x |
| one 8-KiB vector | 127 ns | 298,454 ns | 2,350x |
| 256 64-KiB vectors (16 MiB) | 325,135 ns | 589,177 ns | 1.81x |
| 16 4-MiB vectors (64 MiB) | 1,421,088 ns | 1,908,333 ns | 1.34x |

There is **no observed break-even through 64 MiB** for these three repeat
runs; even the fastest GPU 64-MiB repeat was 1.06x slower than the corresponding
per-vector CPU copy. An earlier benchmark variant showed a marginal GPU win at
16 MiB, so this is a noisy host result and cannot establish a stable
large-buffer crossover.

Copying the two planes preserves X/Z bit encoding exactly. This kernel does not
implement VVP force-mask merging, change detection, VPI callbacks, or scheduler
ordering. Offloading an individual VVP event would need synchronous completion
before the next dependent event; that latency dominates small copies. Batching
unrelated events would need dependency proof. The actual `copy_from_big_`
allocation and host-to-GPU staging would add cost beyond this probe. No VVP
source, install, pinned application checkout, or L0 result was changed.

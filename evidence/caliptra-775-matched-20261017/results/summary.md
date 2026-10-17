# Matched-window Caliptra result against the historical 7.775 cycles/s point

Host: DAN-DESKTOP. One pinned CPU. Three interleaved samples per build.
Test: cptra_ss_test_rom, fixed 100–600 mcycle window (500 cycles).
The window deliberately stops before firmware completion; runner exit 1 and passed=false are expected.
Builds use the same 4-state configuration, Caliptra RTL, QD-BFM, bridge, and deterministic ECC input source.

| Build | Revision | Samples (cycles/s) | Median | Spread | Max RSS |
|---|---|---:|---:|---:|---:|
| baseline | c014c0a7975a | 7.559, 7.639, 7.577 | 7.577 | 1.06% | 1853132 KiB |
| current | afa43b2ffa2d | 9.982, 9.985, 9.930 | 9.982 | 0.55% | 1855240 KiB |

Matched current main vs c014 rerun: +31.75%.
Current main vs historical 7.775 cycles/s point: +28.38%.
The matched same-job c014 median is the primary comparison; 7.775 is the original same-window reference point.
All six generated firmware input manifests and normalized simulator logs matched.

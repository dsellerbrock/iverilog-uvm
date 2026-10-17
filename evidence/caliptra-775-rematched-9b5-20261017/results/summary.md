# Matched-window Caliptra result against the historical 7.775 cycles/s point

Host: DAN-DESKTOP. One pinned CPU. Three interleaved samples per build.
Test: cptra_ss_test_rom, fixed 100–600 mcycle window (500 cycles).
The window deliberately stops before firmware completion; runner exit 1 and passed=false are expected.
Builds use the same 4-state configuration, Caliptra RTL, QD-BFM, bridge, and deterministic ECC input source.

| Build | Revision | Samples (cycles/s) | Median | Spread | Max RSS |
|---|---|---:|---:|---:|---:|
| baseline | c014c0a7975a | 8.121, 8.206, 8.159 | 8.159 | 1.05% | 1853288 KiB |
| current | 9b5fad2afb41 | 10.670, 10.608, 10.188 | 10.608 | 4.54% | 1855780 KiB |

Matched current main vs c014 rerun: +30.00%.
Current main vs historical 7.775 cycles/s point: +36.43%.
The matched same-job c014 median is the primary comparison; 7.775 is the original same-window reference point.
All six generated firmware input manifests and normalized simulator logs matched.

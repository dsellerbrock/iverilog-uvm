# Earl Grey default memory-loader synthesis follow-up

On compiler engine `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`, both default-image RTL synthesis rows passed:

| Core | Result | Compile time | Hard errors | Semantic debt |
|---|---:|---:|---:|---:|
| `lowrisc:systems:chip_earlgrey_asic:0.1` | PASS | 142.314 s | 0 | 0 |
| `lowrisc:systems:top_earlgrey:0.1` | PASS | 128.439 s | 0 | 0 |

The runner staged the same build-local `prim_util_memload.svh` overlay for both rows (SHA-256 `9484798c23f4f441e9e454677429af14bcefcad2d10f74d099acbe4b39475da3`). It guards only the simulation path-printing block with `` `ifndef SYNTHESIS `` and preserves the conditional `$readmemh` path. The profile is limited to the exact default tops, checks their source hashes and empty ROM/OTP image defaults, and is disabled when a `-P` parameter override is present. No OpenTitan source files were changed.

The focused matrix run used one job and returned PASS for both rows. Its setup notices were C/C++ file-type warnings for files omitted from the Icarus compiler source list; no actionable setup warnings remained. Raw compile logs, the staged overlay, and machine-readable result are included here. The input snapshot reports revision `unknown` and `dirty` because it is a copied source tree without clean Git metadata; the hashed RTL inputs are recorded in [result.json](result.json).

This is a two-row compile follow-up. It does not refresh the 309-row compile census or establish a 49-target runtime result on engine `367e…`.

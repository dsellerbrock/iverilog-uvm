# OpenTitan smoke-regression test selection — 2026-09-29

The pinned `rv_timer_sim` and `spi_device_sim` configs assign `rv_timer_random` and `spi_device_flash_mode` to their `smoke` regressions. The completed 49-target corpus selected no test for either target, ran their abstract base sequences, and failed at `cip_base_vseq.sv:123`.

`scripts/opentitan_matrix.py` now resolves a concrete test named by the local smoke regression before its existing name-based fallback. A pre-fix `discover_simulation_targets` check failed for both targets (`pre-fix-red.log`). The same check passes after the change, and comparison with the immutable 49-row census shows that only these two test/sequence selections changed (`post-fix-green.log`). The matrix self-test passes on the corrected script (`matrix-self-test.log`).

Selected runtime uses the same disposable, 46-operation exact-hash OpenTitan overlay copy as the corpus, pinned revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`, current installed `ivl` SHA-256 `2b24c2854756c53c8bd51d8d19906e820700a7fd0d34dbfe4d56de7f3befb0a4` and `vvp` SHA-256 `a3dc04b0409f8572d73d6d5daf982af42206a5c04a083ddb91cc52196a4d0a2e`. The two target pipelines ran concurrently with a 4 GiB per-VVP guard and 1,800-second runtime limit.

| Selected target | Verdict | Evidence |
| --- | --- | --- |
| RV Timer, `rv_timer_random_vseq` | **PASS** | Compile rc 0, runtime rc 0 in 4.1 s, `TEST PASSED CHECKS`, no UVM warnings/errors/fatals or classified debt. |
| SPI Device, `spi_device_flash_mode_vseq` | **DEBT** | Compile rc 0, runtime rc 0 in 125.8 s, `TEST PASSED CHECKS`, no UVM warnings/errors/fatals. Five compile-time semantic notices remain, including three unresolved SPI-agent iterator references; see DD-098. |

The checked-in `selected-result.json` and `selected-result.md` contain both complete row verdicts. The `.log.gz` files preserve each target's setup, compile, and runtime transcripts. To rerun the focused selection check from the compiler repository root, with the same disposable overlaid source still present:

```sh
/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/python - <<'PY'
import os
import sys
from pathlib import Path
sys.path.insert(0, 'scripts')
import opentitan_matrix as matrix
root = Path('/private/tmp/ot-census-speedups-overlays-20260929/source')
python = ['/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/python']
targets = matrix.discover_simulation_targets(python, root, os.environ.copy(), 120)
for core, expected in {
    'lowrisc:dv:rv_timer_sim:0.1': ('rv_timer_random', 'rv_timer_random_vseq'),
    'lowrisc:dv:spi_device_sim:0.1': ('spi_device_flash_mode', 'spi_device_flash_mode_vseq'),
}.items():
    target = targets[core]
    assert (target.dvsim_test, target.uvm_test_seq) == expected
PY
```

The original 49-target result remains unchanged. Caliptra was not run.

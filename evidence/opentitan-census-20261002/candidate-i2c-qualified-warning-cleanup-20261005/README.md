# I2C qualified warning cleanup

On clean OpenTitan revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`,
the candidate engine `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`
passes both focused compile rows with zero hard errors or semantic debt:

| Lane | Core | Result |
| --- | --- | --- |
| SVA | `lowrisc:dv:i2c_sva:0.1` | PASS |
| UVM | `lowrisc:dv:i2c_sim:0.1` | PASS |

The runner stages the existing [qualified I2C patch](../../../docs/conformance/release_overlays/opentitan/i2c_runtime_warning_cleanup.patch)
as build-local, hash-checked overlays. It defers covergroup construction to
the `en_cov` branch, explicitly discards the `pop_back()` result, and removes
the `solve before` clause on the external config field. The paired strict
controls for that constraint are documented in the [previous I2C evidence](../i2c-current-image-overlay/README.md).

See the [machine result](result.json), [matrix report](result.md), and saved
[SVA compile log](sva-compile.log) and [UVM compile log](uvm-compile.log).
This focused compile follow-up does not change the frozen 309-row census or
recheck the 49-target runtime matrix.

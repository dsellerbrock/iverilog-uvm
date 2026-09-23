# OpenTitan SPI Device associative `find_index()` reducer

`reducer.sv` has sparse `bit[7:0]` keys inserted out of order. On PR340 head
`5ebcab90b`, both `-g2017` and `-g2023` reject line 9 with the explicit
associative-array `find_index()` keyed-iteration `sorry`. The pinned released
SPI Device compile reaches the same method in `spi_device_pass_base_vseq.sv`.
The expected result is the matching keys `8'h10, 8'h20`, not array positions.

Run from the campaign worktree:

```sh
local-install/bin/iverilog -g2017 -s assoc_find_index_reducer -o /tmp/assoc_find_index.vvp evidence/ot-spi-assoc-find-index-20260923/reducer.sv
local-install/bin/vvp /tmp/assoc_find_index.vvp
```

Repeat with `-g2023`. Compilation alone is insufficient; require the runtime
PASS marker and focused empty, no-match, and key-type controls.

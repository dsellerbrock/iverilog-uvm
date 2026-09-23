# Caliptra/Adams Bridge mixed struct-member index reducer

Clean Adams Bridge v2.0.3 `masking_tb` uses `inputs.x_boolean[j][0]`: the
first index selects an unpacked struct-member element, and the second selects
its packed bit. `red.sv` isolates that read; `whole_element_control.sv` checks
the neighboring accepted whole-element read.

Compile either source with this worktree's
`local-install/bin/iverilog -g2017 -s top -o <output.vvp> <source.sv>`
(repeat with `-g2023`), then run a successful image with
`local-install/bin/vvp <output.vvp>`.

On the source tree containing `5afbe4c7f` and `e4e2f00ea`, RED fails in both
editions with `Got 2 indices, expecting 1 to index struct member x`; the
whole-element control compiles and prints `PASSED whole element indexing`.
Other whole-array port errors remain in the pinned `masking_tb` census row.
The full local tool transcript is retained in the workspace evidence
directory of the same name.

# OpenTitan SPI class-event `.triggered` reducer

The pinned Earlgrey-PROD-M6 SPI Device compile rejects three `spi_item`
event-property `.triggered` reads. `class_event_triggered.sv` isolates the
per-instance value and wakeup behavior; `class_event_wait_control.sv` checks
ordinary per-instance event waits independently.

From this repository root, compile either source with the worktree's
`local-install/bin/iverilog -g2017 -s <module> -o <output.vvp> <source.sv>`
(repeat with `-g2023`), then run a successful image with
`local-install/bin/vvp <output.vvp>`.

On the source tree containing `5afbe4c7f` and `e4e2f00ea`, the `.triggered`
reducer fails compilation in both editions with `Class event_box has no
property ev`; ordinary waits compile and print `CLASS_EVENT_WAIT_CONTROL_PASS`.
The failure path also warns about a compile-progress fallback, which a future
fix must eliminate rather than silently accept. This is RED evidence, not a
SPI Device DV pass. The full local tool transcript is retained in the
workspace evidence directory of the same name.

# Multi-object class-event list reducer

With the Icarus compiler built from PR339 source head `a338704e4` (merged
as `6fd804a39`), `reducer.sv` compiles in both `-g2017` and `-g2023` but
fails at time 2: triggering `b.ev` never wakes `@(a.ev or b.ev)`.

Run from this repository root with the active compiler and runtime:

```sh
local-install/bin/iverilog -g2017 -s multi_object_event_control -o /tmp/multi_object_event_control.vvp evidence/ot-class-event-multi-object-list-triage-20260923/reducer.sv
local-install/bin/vvp /tmp/multi_object_event_control.vvp
```

Repeat with `-g2023`. The generated VVP currently declares
`Ewait_0 .event/or E_ev,E_ev` and executes `%wait Ewait_0`, while
`-> b.ev` executes `%evt/obj 0`. The object identity is lost in the wait.
This is a separate, unfixed defect from `.triggered` expression reads.

# Named-event `triggered()` call crash

`reducer.sv` aborts `ivl` at `elab_expr.cc`'s `sub_expr` assertion on the
current OpenTitan class-event candidate. The parenthesis-free `ev.triggered`
path is separate. Baseline verification and an implementation ticket are
pending; do not treat this reducer as a regression introduced by the active
patch without a baseline comparison.

From the campaign worktree, run:

```sh
local-install/bin/iverilog -g2017 -s plain_event_triggered_call_crash -o /tmp/plain_event_triggered_call_crash.vvp evidence/ot-event-triggered-call-crash-20260923/reducer.sv
```

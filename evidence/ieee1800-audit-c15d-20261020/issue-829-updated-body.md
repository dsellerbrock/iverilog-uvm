**Clause:** 2017 §15.5.3 p.361 / 2023 §15.5.3.
**Normative (the standard example):** `event done, blast; event done_too = done; task trigger( event ev ); -> ev; endtask ... fork @ done_too; #1 trigger( done ); join` "shows ... how an event can be passed to a generic task that triggers the event."
**Probes:** tests/1800_audit/c15/ev/ev_formal_only.sv (`module t; task trigger(event ev); -> ev; endtask endmodule`) and ev_task_formal.sv (the same task called from a fork).
**Observed** (identical under -g2017 and -g2023): `ev_formal_only` fails to compile with rc=2, "syntax error" at the task declaration. Control `ev_call_fork_only.sv` (an ordinary task formal called from a fork with a wait on an event) compiles with rc=0, so the failure is the event-typed formal argument, not the fork.
**Expected:** a task formal of type event is accepted, and the example prints `E2 1`. The other isolated event probes pass. Related, not covering: #699, closed #439 and #441.

Provenance: Icarus current main `cc25756d` (13.0-devel). Probes on branch `m7-1800-audit-c08`, `tests/1800_audit/c15/ev/`. Logs: `evidence/ieee1800-audit-c15d-20261020/attempt-02-lead-scope-reducers/.

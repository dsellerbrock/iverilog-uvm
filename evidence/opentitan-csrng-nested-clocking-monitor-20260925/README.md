# CSRNG nested clocking monitor baseline

This is paired strict baseline evidence for `OT-CSRNG-NESTED-CLOCKING-MONITOR`.
The legal reducer reproduces `@(cfg.vif.child.mon_cb)` and reads the sampled
`valid && ready` through a class-held parent VIF. It exercises two physical
parents on independent 10 ns and 14 ns clocks, rebinds at 8 ns, and checks
wake timestamps and both handshake values. Direct child and direct parent
clocking VIF controls pass at the first edge.

The result is **RED in both editions**. Compile exits 0 with
`Failed to evaluate event expression 'cfg.vif.child.mon_cb' (compile-progress:
event skipped)`. Runtime exits 1: the skipped event resumes its task
immediately, at 0 ns for the p0 wait and 8 ns for the rebound p1 wait, rather
than waiting for p0 at 5 ns and p1 at 21 ns. The nested monitor reads `000`
for sampled valid, ready, and handshake. The direct controls at the initial
5 ns edge report `direct_child=1/1 direct_parent=1`.

The reducers use the existing PR363 private tools only:

```sh
/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-csrng-nested-vif-20260925/local-install/bin/iverilog -g2017 -s tb -o evidence/opentitan-csrng-nested-clocking-monitor-20260925/reducer-2017.vvp evidence/opentitan-csrng-nested-clocking-monitor-20260925/reducer.sv
/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-csrng-nested-vif-20260925/local-install/bin/vvp evidence/opentitan-csrng-nested-clocking-monitor-20260925/reducer-2017.vvp
/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-csrng-nested-vif-20260925/local-install/bin/iverilog -g2023 -s tb -o evidence/opentitan-csrng-nested-clocking-monitor-20260925/reducer-2023.vvp evidence/opentitan-csrng-nested-clocking-monitor-20260925/reducer.sv
/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-csrng-nested-vif-20260925/local-install/bin/vvp evidence/opentitan-csrng-nested-clocking-monitor-20260925/reducer-2023.vvp
```

Both compiler commands exit 0 and both runtime commands exit 1. Exact streams
are in `reducer-{2017,2023}.{compile,runtime}.log`; their SHA-256 values and
tool fingerprints are in [result.json](result.json).

The same behavior check is registered as a paired legacy/JSON ivtest. Its
gold describes the intended post-fix pass; current PR363 baseline replays of
that registered source still compile 0 and run 1 in both editions. The exact
baseline streams are `ivtest-{2017,2023}.{compile,runtime}.log`. The pair is
in `regress-sv.list`, `regress-vvp.list`, and the nested-value focused legacy
and JSON lists. Existing paired nested-null and hidden-modport controls remain
in the general regression manifests; no duplicate negative fixture was added.

Existing paired null-value and hidden-clock controls were replayed; the exact
class-held nested event path also has paired negative ivtests. The null-parent
event test compiles 0 and runs 1 in both editions on this baseline, but its
current output is the test's `FATAL` trap after the skipped event resumes. Its
post-fix gold expects the runtime null-interface error. The hidden-child
modport test compiles 2 in both editions here. The baseline emits the focused
IEEE 1800-2017/2023 §25.5 rejection plus a duplicate `:0` error and skipped
event warning; the expected gold pins one focused rejection. Raw logs are
`null-event-{2017,2023}.{compile,runtime}.log` and
`hidden-child-{2017,2023}.compile.log`.

The exact boundary commands were:

```sh
for edition in 2017 2023; do
  /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-csrng-nested-vif-20260925/local-install/bin/iverilog -g$edition -s sv_vif_class_nested_value_null_no_instance_fail -o evidence/opentitan-csrng-nested-clocking-monitor-20260925/null-$edition.vvp ivtest/ivltests/sv_vif_class_nested_value_null_no_instance_fail.v
  /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-csrng-nested-vif-20260925/local-install/bin/vvp evidence/opentitan-csrng-nested-clocking-monitor-20260925/null-$edition.vvp
  /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-csrng-nested-vif-20260925/local-install/bin/iverilog -g$edition -s sv_clocking_class_vif_modport_unexported_clocking_fail -o evidence/opentitan-csrng-nested-clocking-monitor-20260925/modport-$edition.vvp ivtest/ivltests/sv_clocking_class_vif_modport_unexported_clocking_fail.v
done
```

The path-specific negative commands were:

```sh
for edition in 2017 2023; do
  /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-csrng-nested-vif-20260925/local-install/bin/iverilog -g$edition -s sv_vif_nested_clocking_event_null_parent_fail -o evidence/opentitan-csrng-nested-clocking-monitor-20260925/null-event-$edition.vvp ivtest/ivltests/sv_vif_nested_clocking_event_null_parent_fail.v
  /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-csrng-nested-vif-20260925/local-install/bin/vvp evidence/opentitan-csrng-nested-clocking-monitor-20260925/null-event-$edition.vvp
  /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-opentitan-csrng-nested-vif-20260925/local-install/bin/iverilog -g$edition -s sv_vif_nested_clocking_event_hidden_child_fail -o evidence/opentitan-csrng-nested-clocking-monitor-20260925/hidden-child-$edition.vvp ivtest/ivltests/sv_vif_nested_clocking_event_hidden_child_fail.v
done
```

The interpretation of nested access combines IEEE 1800-2017/2023 §§14.10,
14.13, and 25.9/25.9.1; the exact class-held parent to nested child spelling
is inferred from those rules. This reducer does not qualify a complete CSRNG
monitor, scheduler behavior beyond these observed event/sample checks, or
released CSRNG DV.

## Final private candidate

The repair types the named child clocking block through the selected parent
VIF, rewrites sampled members, and carries the selected child into the existing
dynamic VIF event descriptor. The VVP target evaluates that receiver when each
wait arms. No VVP runtime opcode or pinned application source changed. A
resolved child with a missing clocking name now fails compilation instead of
silently skipping its event. The separate paired missing-clock baseline is in
`missing-clock-{2017,2023}.baseline.compile.log` and
`missing-clock-baseline.json`.

The final private `ivl` is SHA-256
`af9af369147ce1e5fadaaef7dea6e4a035e63cca737342a90ffed3f70bccf84b`.
Paired strict 2017/2023 legal event/sample/rebind, null, hidden-modport, and
missing-clock tests pass [22/22 legacy and 22/22 JSON](candidate-focus-final-v4.log).
The selected child wakes at 5 ns and 21 ns after the parent VIF is rebound;
both sampled handshake branches are checked. Null runtime access is fatal;
hidden and nonexistent clocking paths produce focused compile errors. `make
check` also passes. This is IEEE reducer evidence, separate from released DV.

The unchanged pinned CSRNG revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`
with the existing named disposable overlay compiles under explicit
`-g2017 -gcommercial-unsafe`. The [final compile log](candidate-release-compile-final.stderr.log)
no longer skips the command monitor event or assumes its sampled condition
false. It still ignores the `int_state_read_enable_c` constraint item. Native
AES DPI was rebuilt for the [final image](candidate-release-dpi-final.json).
The [released runtime](candidate-release-runtime-final.stdout.log) exits 1 at
1,000 ps on the prior unknown CSR backdoor field, `TEST FAILED CHECKS`, and a
follow-on TL end-of-simulation assertion. There is no meaningful checked
command traffic. This is **0/1 released OpenTitan CSRNG DV in nonstandard
Icarus compatibility mode**, regardless of the strict reducer results. Exact
commands, tool hashes, and outcomes are in [result.json](result.json) and the
candidate compile/runtime JSON records.

The final private tool also passes the [broad legacy gate](candidate-broad-legacy-final.log):
6,609 total, 6,604 passed, zero failed, two not implemented, three expected
failures; VPI 131/131, negatives 155/155, and runtime invariants 15/15.
[Full JSON/VVP](candidate-full-json-final.log) passes 3,648/3,648. The
[real-DPI UVM suite](candidate-real-dpi-uvm-final.log) passes 358/358 with
zero failures or skips. Four neighboring event-list negative cases pass in
both [legacy](candidate-event-list-neighbor-legacy.log) and
[JSON](candidate-event-list-neighbor-vvp.log) after their golds cease expecting
an event-skipped warning following an explicit compile error. These checks do
not change the 0/1 released CSRNG DV verdict.

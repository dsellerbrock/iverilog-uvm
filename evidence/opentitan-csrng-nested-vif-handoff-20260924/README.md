# DD-055: OpenTitan CSRNG nested virtual-interface handoff

This is a focused Icarus diagnostic, **not a CSRNG DV pass**. The pinned
OpenTitan checkout is `a78922f14a8cc20c7ee569f322a04626f2ac6127`.
Its source and the installed tools were not changed. The uninstrumented
private VVP replay of `csrng_smoke_test` stops at 0 ps with
`%wait/vif/posedge attempted to use a null or non-virtual interface`, one
TL-UL end-of-simulation assertion, and `TEST FAILED CHECKS`. The VVP process
returns 0 despite those failure markers. The replay result is in `original_private_runtime_result.json`; its raw log is retained locally.

The original 73 MB VVP image has SHA-256
`932928e71a04af7f8be2a08eabecf6f96da81226bdf0c394033db0ed566d576c`.
A disposable copy added one `$display` before each of its 47
`%wait/vif/posedge` instructions; deleting those additions restores the
original hash byte-for-byte. The four waits reached at 0 ps were TL monitor
site 47, push-pull monitor site 37, CSRNG monitor site 14, then push-pull
monitor site 34 (original image line 716659). Site 34 belongs to the
129-bit `m_edn_agent[1].m_genbits_push_agent.monitor` specialization and
maps to `hw/dv/sv/push_pull_agent/push_pull_monitor.sv:25`,
`@(posedge cfg.vif.rst_n)`. The opcode trace summary is in `opcode_probe_result.json`; its raw log is retained locally.

Hash-checked, disposable source overlays added only diagnostic `$display`
calls; three local `*.probe.diff` files retain the exact changes. The
parent `m_edn_agent[0/1]` CSRNG VIF is nonnull, and each nested push-pull
agent successfully gets a config object from `uvm_config_db`; however both
32-bit command and 129-bit genbits agents have null `cfg.vif`. The monitor
sees the *same* config object and its VIF is null immediately before the
failing wait. The scalar AES-halt and entropy-source agents have nonnull
VIFs. The parent overlay's `cmd_vif_null=32` and `genbits_vif_null=32`
fields are **not boolean measurements**: Icarus lowered those particular
nested comparison display arguments to a blank string, printed as ASCII 32.
The `parent_vif_null=0` result is valid. The overlay result JSONs record those runs; raw streams remain local. Both overlay runs retain the same 0 ps VIF error, TL-UL
assertion, and `TEST FAILED CHECKS` marker, with zero pass markers.

The original bytecode excerpt shows the stronger cause: in
`csrng_agent.build_phase`, calls to `uvm_config_db#(virtual
push_pull_if)::set` for `cfg.vif.cmd_push_if` and
`cfg.vif.genbits_push_if` emit stores for context, instance path, and
`"vif"`, but no `%store/obj` for the `value` actual before either call.
The callee's `value` formal exists in the image. Therefore a default null
value is passed at the handoff; the monitor's null VIF is downstream of
compiler lowering, not an absent parent VIF or lost monitor config alias.
The locally retained bytecode excerpt gives original line numbers and image hash.

The paired minimal check uses the **private current-source** compiler and
VVP, with strict `-g2017` and `-g2023` (no unsafe flag):

| Case | 2017 | 2023 |
| --- | --- | --- |
| Parent interface assigned to class VIF | compile and runtime pass | compile and runtime pass |
| Concrete nested child passed directly | compile and runtime pass | compile and runtime pass |
| Child reached through class-held parent VIF, `sink.put(cfg.vif.nested)` | code-generation failure `-3` | code-generation failure `-3` |

Sources are `parent_vif_control.sv`, `direct_nested_control.sv`, and
`nested_vif_put_only.sv`; exact commands, exit codes, and hashes are in
`paired_nested_vif_result.json`, with raw streams retained locally. `-3` means ordinary process
emission failed (`emit.cc:819`), rather than a successful executable.

The likely compiler fault boundary is `PCallTask::elaborate_build_call_` in
`elaborate.cc`: it builds the copy-in assignment for the `value` formal from
the nested actual. Its r-value comes from
`PEIdent::elaborate_expr_class_field_` in `elab_expr.cc`, which walks
`cfg.vif.genbits_push_if`; `tgt-vvp/stmt_assign.c` emits a `%store/obj` for a
valid object assignment. Instrumenting the actual `NetExpr`/`NetAssign` at
that boundary is the next narrow check. The current evidence does not yet
distinguish a missing frontend assignment from a target emission failure in
the full CSRNG build, so no compiler fix is claimed here.

Private compiler wrapper SHA-256:
`9a97c88bc5e1dd26a67d6fe41690a6c5b13988ac34cfe859788cec24eb3068e9`;
private compiler engine SHA-256:
`302d709432e386f59a1c849d91c2fbe496b858dfde870641496888e7290db890`;
private VVP SHA-256:
`bbe72e9db2dcffd0269173e21c52f6a315b9bd97f17dfda225a2c004f8ea2a8f`.
The DV replay used `-g2017 -gcommercial-unsafe`, as recorded in the overlay
compile results. Source lists, command files, raw streams, and large generated VVP images
remain local diagnostic artifacts; the paired reducer and compact results
are the durable evidence for this discovery.

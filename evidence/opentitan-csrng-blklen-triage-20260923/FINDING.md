# CSRNG `BlkLen` part-select triage

Source: unchanged pinned OpenTitan CSRNG `tb.sv:152,162`, compiled with the
campaign `local-install/bin/iverilog` after the separate interface-name fix.
The 12 elaboration errors in
`/tmp/ivl-focus-20260923/csrng-parser-candidate-compile.log` reduce to two
assertion expressions repeated by assertion expansion. Each uses a module
instance path, `tb.dut.u_csrng_core.u_csrng_ctr_drbg_{gen,upd}.BlkLen`, as the
width of an indexed `-:` part-select.

IEEE 1800-2017 §11.5.1 and IEEE 1800-2023 §11.5.1 require the indexed
part-select width to be a positive constant integer expression. Annex A
defines the width as `constant_expression`, whose parameter primary is a
`ps_parameter_identifier`. That identifier admits package/class scope or a
path of **generate blocks**, but not a path through module instances. The
released testbench form therefore relies on a commercial-tool extension;
Icarus' rejection is not evidence of a conformance defect. A separate
`g.BlkLen` generate-block probe is legal by the Annex A grammar yet rejected
by this Icarus build; it is a distinct compiler gap, not the cause of these
OpenTitan errors.

The actual child modules have `parameter int BlkLen = 128`, supplied from
`csrng_core.sv:66` (`localparam int BlkLen = 128`) through parameter overrides.
The narrow disposable release overlay is to replace only the two part-select
width operands in `tb.sv` with a `tb`-local positive constant equal to 128,
while leaving the hierarchical base expressions intact. This is safe only
for the pinned parameterization and should be checked if the application
revision changes. No released source or compiler was edited here. A blanket
relaxation of hierarchical names in constant expressions would be wider than
this compatibility need. `-gcommercial-unsafe` does not change the standard's
constant-expression grammar.

`results.json` captures exact paired 2017/2023 compiler and simulator
commands, exit codes, and diagnostics for these probes:

| Probe | 2017 | 2023 | Meaning |
| --- | --- | --- | --- |
| `hierarchical_parameter_width` | compile 2 | compile 2 | Pinned `-:` form, reduced |
| `local_parameter_width` | compile/run 0 | compile/run 0 | Legal replacement width |
| `runtime_variable_width` | compile 2 | compile 2 | Illegal nonconstant width |
| `hierarchical_parameter_value` | compile/run 0 | compile/run 0 | Instance parameter readable as ordinary value |
| `generate_parameter_width` | compile 2 | compile 2 | Legal generate-scoped boundary gap |

The only potentially warranted Icarus implementation lane from these probes
is generate-scoped parameter constant evaluation. The released instance-path
case needs no default-language compiler change.

# Caliptra synthesis assertion transparency

Caliptra RTL is an unmodified, read-only compatibility workload. With
concurrent assertions enabled, several synthesis manifests reached a generated
checker assignment whose right side contained the internal
`$ivl_clocking_sample` operation. The synthesis pass treated the checker as
hardware, expression synthesis returned no signal, and
`NetAssignBase::synth_async` aborted on an assertion.

Concurrent `assert property`, `assume property`, and `cover property` lowering
now marks only the compiler-generated verification processes. The synthesis
pass removes those processes while retaining the user's hardware processes.
The provenance is a compiler-owned boolean carried from parse form to netlist,
not an attribute that source text or VPI can forge; the positive reducer places
an identically spelled source attribute on a real data-path process and proves
that process is still synthesized.
Normal simulation still elaborates and executes the checkers. An ordinary RTL
assignment whose expression cannot be structurally synthesized is not hidden:
it produces a controlled diagnostic and compilation failure rather than an
abort.

`synth_concurrent_assertion_transparent` pins the positive synthesis behavior
and a live data path. `synth_property_rhs_no_crash_fail` pins the loud boundary
for a legal class-property expression that does not yet have hardware lowering.
The pre-fix compiler aborts on both reducers.

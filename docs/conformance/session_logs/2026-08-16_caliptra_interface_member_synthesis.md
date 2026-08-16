# Caliptra interface-member synthesis

Caliptra RTL and OpenTitan RTL are unmodified, read-only compatibility
workloads. This change is entirely in Icarus Verilog and its regression suite.

Icarus represented an interface/modport formal as a simulation handle. During
synthesis, a property such as `port.member` consequently reached structural
expression and l-value lowering as a one-bit object handle rather than the
member signal. Direct bindings, forwarded formals, interface arrays, and a
selected synthesis root with modport ports then either produced a controlled
"cannot synthesize property" error or reached an internal assertion.

The netlist now preserves a static binding from an interface formal to its
concrete interface instance, or to the formal that forwards it. Synthesis
resolves member reads, writes, sensitivity, output maps, and direct member
events through that binding. Compiler-generated run-time binding processes are
tagged as transient and removed from the hardware process set. When a module
with modport ports is itself selected as the synthesis root, Icarus creates
full-width structural member signals from the interface declaration and the
modport directions rather than treating the members as one-bit handles.

The permanent reducers cover:

- direct interface-instance to modport binding;
- formal-to-formal forwarding through another module;
- constant elements of interface-port arrays;
- scalar and multidimensional packed members;
- a selected synthesis root whose only connection surface is a modport; and
- unchanged simulation behavior for the direct bridge.

The unchanged Caliptra `el2_veer_wrapper` synthesis replay now reports zero
interface/member errors and zero crashes in `el2_mem.sv` lines 101--136, where
the pre-fix compiler reported 31 errors. The complete replay still fails on
separate Icarus synthesis limitations, chiefly `always_*` and asynchronous
control shapes. This is therefore a closure of the static interface-member
binding cluster, not a claim that the entire Caliptra design synthesizes.

Run-time-selected interface-port array elements and other dynamic interface
identities remain explicitly unsupported in structural synthesis; they are not
silently lowered to an arbitrary instance.

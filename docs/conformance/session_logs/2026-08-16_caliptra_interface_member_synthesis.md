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

This closure is validated for the null and VVP synthesis targets used by the
Caliptra acceptance flow. Text/FPGA targets still need an explicit ABI for
flattening one interface/modport formal into multiple named scalar/vector
ports; the focused JSON configurations therefore mark Verilog-95 translation
as not implemented rather than treating its current output as equivalent.

## Integral member warning classification

The synthesis checks attached to `always_comb`, `always_ff`, and
`always_latch` formerly classified an assignment from the root signal's type.
An integral assignment such as `req_if.valid = next_valid` was consequently
reported as non-synthesizable merely because the root `req_if` was an
interface handle. The warning now uses the fully resolved l-value type, after
member, element, and packed-select traversal. Direct assignments to real and
other genuinely non-integral variables retain their existing warnings.

`sv_synth_integral_member_lvalue` value-checks integral interface and packed
struct members in all three specialized `always_*` process kinds. The old
compiler emits three false warnings on this reducer; the corrected compiler
emits none, runs `PASSED`, and Slang 11 accepts it with zero errors and zero
warnings. This removes a large repeated warning cluster from the unchanged
Caliptra design without suppressing unsupported constructs or changing their
semantics.

The unchanged Caliptra top-level VVP compile provides the integration count.
Both pre-fix and corrected compilers exit 0 under the resource guard. The
pre-fix log contains 180 instances of this false warning among 202 total
warnings; the corrected log contains zero such instances and 22 total
warnings. The remaining 22 are the separately documented conservative
interface-member sensitivity warnings. The corrected compile took 15.30
seconds and peaked at 870,858,752 bytes of RSS, below the 1 GiB limit.

## Tool and invocation notes

- macOS `/usr/bin/bison` is Apple Bison 2.3 and cannot regenerate this tree;
  put Homebrew Bison 3.8.2 first in `PATH`.
- A focused object build immediately after `configure` can compile the object
  and then fail moving its dependency file if the generated `dep/` directory
  has not yet been initialized. Run the normal bootstrap build first, or
  create that generated directory before requesting an individual object.
- A yielded command session is still running until its session identifier
  reports an exit code. Poll that exact session; do not launch a replacement
  build merely because the first output chunk returned.
- Caliptra's `+timescale+1ns/1ps` belongs in an Icarus command file. Passing
  it as a free driver argument is ignored and can make the next option appear
  to be an input filename. A nested `-f` path is resolved relative to the
  command file containing it, not the shell's current directory, so an
  evidence-directory wrapper must use an absolute path for
  `src/integration/config/caliptra_top.vf`.
- The full Caliptra file list requires all three environment settings:
  `CALIPTRA_ROOT=<checkout>`,
  `CALIPTRA_PRIM_ROOT=<checkout>/src/caliptra_prim_generic`, and
  `CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic`. Omitting the latter
  two expands primitive filenames to paths such as `/rtl/_flop_en.sv`.
- This checkout was configured with `CFLAGS=-g0 -O2` and
  `CXXFLAGS=-g0 -O2`. On this host, debug information for the very large VVP
  translation unit can exceed the per-process 45-second CPU cap even though
  the optimized non-debug build remains comfortably bounded.
- Every compiler and simulator process tree in this validation used the
  pinned `resource-runner` with 45 seconds of CPU per process and 1 GiB of
  aggregate RSS. Ambient `iverilog` and `vvp` binaries were not used.

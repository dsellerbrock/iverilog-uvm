# 2026-07-15 — M10: DPI and open arrays (PR #76)

Directive: "Do M10 and continue to iterate until M10 is fully closed."

Before this milestone, DPI was a parse-level accommodation with a
broken runtime: only `import "DPI-C" function` parsed (tasks were
syntax errors, the `c_identifier =` alias form was unparseable,
`export` silently dropped); the runtime `%dpi/call` opcodes ignored
the per-argument signature entirely and dispatched through casted
function pointers assuming uniform int32 (or uniform double)
argument lists — mixed int/real/string signatures called with a
broken ABI, arguments were capped at 8, a 3-argument real function
went through a 4-argument cast (UB), >32-bit integers truncated
silently, and output/inout arguments and open arrays did not exist.

## M10-1: libffi marshaling core

`vvp_dpi_call()` (vvp/vvp_dpi.cc) builds an exact `ffi_cif` per call:
per-argument types (sint8..uint64 by width and signedness, double,
pointer) and the proper return kind, dispatched by libffi with the
platform ABI's register classes and sub-word extensions. Argument
values live in typed union slots (endianness-proof). A legacy
casted-pointer fallback remains for builds without libffi
(uniform-type signatures only; anything else is a loud runtime
diagnostic, never a broken call).

The compiler emits a signature string in the opcode text
(`"c_name|tokens"`), one token per argument: `[+][u]<letter>` with
`+` output direction, `u` unsigned, letters `b/h/i/l` for 2-state
integers by width (byte/shortint/int/longint/chandle — chandle is
represented as a 64-bit atom in this fork), `g` for 1-bit scalars
(svBit/svLogic unsigned-char ABI, 4-state encoding sv_z=2/sv_x=3),
`r` real, `s` string, `o` open array. The four `%dpi/call/*` opcodes
share one worker that pops each argument from its proper stack
(int64-capable) and always keeps the stacks balanced on missing
symbols or unmarshalable signatures (a default result is pushed).

Build: `-lffi -DUSE_LIBFFI` wired like the existing z3 dependency
(vvp/Makefile.in); libffi added to all three CI platforms (apt
`libffi-dev`, brew `libffi` with keg-only include/lib exports, MSYS2
`mingw-w64-*-libffi` in the PKGBUILD depends/makedepends).

Bug found and fixed on the way: **void DPI function call statements
were silently elided** — DPI imports have empty pform bodies and the
empty-call optimization in `elaborate_build_call_` dropped the calls
outright (the marshaling body is synthesized later, in the code
generator). DPI imports (functions and tasks) are now exempt.

## M10-2: grammar — tasks, aliases, export sorries

- `import "DPI-C" [context] task ...` parses and links (pure on a
  task is a hard error per 35.4 — negative test).
- `import "DPI-C" c_name = function/task sv_name(...)` binds the C
  symbol name independently of the SV name.
- All four `export "DPI-C"` forms (function/task × plain/alias) are
  loud compile-progress sorries naming the affected symbol (were:
  function form silently dropped, task forms syntax errors).
- Zero new bison conflicts (458 s/r, 1103 r/r — identical counts and
  identical pre-existing useless-rule warnings before and after).
- Plumbing: DPI flag + C name moved from PFunction to the shared
  PTaskFunc base; t-dll copies them for TASK scopes;
  draw_task_definition synthesizes the marshaling body for DPI tasks
  (all ports are arguments, void call).

## M10-3: output/inout arguments

Output and inout arguments pass by pointer and copy back (35.5.6):
the runtime seeds a typed slot with the incoming value (exact for
inout; a pure output's entry value is undefined per the LRM, so
seeding is harmless), passes its address, reads the callee-written
value back, and pushes it above the return value; the synthesized
body stores the outputs into the port variables in reverse order and
the standard call machinery copies them out to the caller's actual
lvalues (this machinery was verified working for native functions
and tasks before reusing it). Output integer widths are restricted
to exact atom widths (8/16/32/64) or 1-bit scalars so the pushed
width always matches the port width — other output widths are loud
sorries. String outputs marshal as `const char**` with an immediate
copy of the callee-owned result.

## M10-4: open arrays

One-dimensional open-array arguments (`input int arr[]`, 35.5.6.1)
for dynamic arrays of 2-state atoms (byte/shortint/int/longint,
signed or unsigned) and real. `vvp_darray_atom<T>`/`vvp_darray_real`
expose their contiguous storage through new virtuals; the `o` letter
marshals a handle struct (data/length/elem_bytes) by pointer; the
svdpi accessor subset — svDimensions, svSize, svLow, svHigh, svLeft,
svRight, svIncrement, svSizeOfArray, svGetArrElemPtr(1), and
svGetArrayPtr — is exported from the vvp executable (rdynamic on
POSIX, vvp.def entries on Windows) so `vvp -d lib.so` libraries
resolve it. Element pointers point directly into simulation storage:
C-side writes are immediately visible, no copy-back, and direction
prefixes are unnecessary for open arrays. Non-atom element types are
compile-time sorries; a non-darray object reaching an `o` argument at
runtime is a loud diagnostic with an empty (NULL-data) handle, and
out-of-range svGetArrElemPtr1 returns NULL. A new installed `svdpi.h`
carries the implemented subset.

## Real-UVM closure check

Compiling UVM (`uvm_pkg.sv`) WITHOUT `-DUVM_NO_DPI` completes with
rc=0 and every DPI construct accounted for: the regex, command-line,
and polling imports (chandle handles, `output int exec_ret`, bit
scalars, strings, ints) become real marshaled imports; the only DPI
diagnostics are the recorded sorries — 4× `uvm_hdl_*` (1024-bit
`uvm_hdl_data_t` needs svLogicVecVal) and 2× `export "DPI-C"`.
Nothing DPI-related is silently dropped anymore. (The regression
harness keeps `-DUVM_NO_DPI`: running the real DPI layer needs a
compiled uvm_dpi C library at simulation time, which is a harness
integration question, not a language gap.)

## Tests

- tests/m10_dpi_mixed_test.{sv,c} — 16 checks: mixed int/real/string
  orders, longint/chandle 64-bit round trips, byte/shortint sign
  extension, unsigned widths, a 12-argument call, 3-arg real, void
  with mixed args, svLogic scalar 0/1/z/x encodings.
- tests/m10_dpi_task_alias_test.{sv,c} — imported tasks mutating
  C-side state read back through alias-bound functions; alias with
  mixed real/int args; alias-bound task.
- tests/m10_dpi_output_test.{sv,c} — 18 checks: multiple int outputs
  with a return value, real outputs, inout longint swap through an
  imported task, inout int round trips, string output, byte/shortint
  sub-word pointer writes, svBit/svLogic 1-bit outputs including an
  X coming back from C.
- tests/m10_dpi_openarray_test.{sv,c} — 9 checks: int sum, empty
  array, element write-back visibility, longint and real elements,
  inout byte doubling in place, geometry consistency, NULL on
  out-of-range access.
- tests/negative/m10_dpi_pure_task.sv — pure DPI task rejected.
- Existing dpi_basic_test/dpi_real_test pass unchanged through the
  new marshaler.

## M10 recorded corners (at close)

- **svLogicVecVal / svBitVecVal packed-vector marshaling** (>64-bit
  or 4-state-exact vectors, incl. UVM's 1024-bit `uvm_hdl_data_t`):
  compile-time sorry; ≤64-bit 4-state vectors pass by value with a
  2-state-coercion warning (X/Z→0).
- **export "DPI-C"** (C calling into SV): loud sorry naming the
  symbol.
- Open arrays beyond 1-D dynamic arrays of atoms/real: packed-vector
  elements, string elements, queues (`q[$]` formals), associative
  arrays, multi-dimensional open arrays — compile-time sorries.
- Output integer args of non-atom widths (e.g. `output bit [4:0]`)
  — compile-time sorry (inputs of any width ≤64 are fine).
- X/Z bits in 2-state integer arguments coerce to 0 (DPI integer
  types are 2-state; svLogicVecVal is the exact carrier — see above).
- chandle is represented as a 64-bit integer atom fork-wide (parse
  maps it to longint); null compares work, but chandle-specific type
  checking (H.8) is not enforced.
- svdpi.h ships the open-array + scalar subset only (no
  svPutBitselLogic/svGetBitselLogic bit-level accessors, no
  svScope/svGetScope context API, no sv2 packed accessors).
- `import "DPI-C" context` is accepted and ignored (every import
  already runs in the simulator process; context-sensitivity has no
  additional meaning in this runtime yet).
- DPI functions returning >64-bit vectors: sorry.
- Legacy non-libffi fallback builds: uniform-type signatures only,
  mixed/real-output/9+-arg calls are loud runtime diagnostics.

## Promotion evidence

Recorded below after the full sweeps.

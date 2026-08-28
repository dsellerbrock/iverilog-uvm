# Positional queue/dynamic-array conversion and call boundaries (2026-08-28)

## Scope and provenance

This increment was developed in
`iverilog-uvm-opentitan-array-conversion-after244-arm64-20260828` on branch
`agent/opentitan-array-conversion-after244-arm64-20260828`, based exactly on
`origin/main` commit `00c21f05c6cf818a4d626237e8c2301d7379518b` after PR
#244. Production code and permanent regressions are committed and pushed as
`674e38b5f`. The compiler and VVP runtime were built and installed from this
worktree with native Apple Silicon tools, Homebrew Bison 3.8.x, and the shared
45-second per-process CPU guard without an RSS ceiling.

OpenTitan was unchanged at
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`. The targeted application replay
used native ARM64 Python 3.13, FuseSoC 2.4.5, Edalize 0.6.3, and the generated
file lists and setup commands produced by the repository matrix driver.
OpenTitan, Caliptra, Accellera UVM, and generated application source were not
modified.

The locally retained, ignored IEEE 1800-2017 and IEEE 1800-2023 PDFs were read
for the clauses below. The two editions agree on the behavior used by this
increment.

## Normative audit

### Assignment and destination kind

Clause 7.6 makes a fixed unpacked array, dynamic array, queue, or slice
assignment compatible with another such value when their slowest-varying
element types are equivalent and any fixed-size destination has the same
number of elements. The outer kinds need not match. If the target is a queue
or dynamic array, it is resized to the source element count, then elements are
assigned in left-to-right order. Faster-varying dimensions remain subject to
type equivalence.

That rule requires a destination-typed value, not a source object stored under
a differently typed declaration. A previous-main `real[$]` to `real[]`
assignment duplicated the queue object. Generic `.size()` and indexed reads
hid the representation mismatch because both runtime classes implement them.
Passing the result to a real DPI open array exposed it: a dynamic array needs
atom-contiguous storage and the leaked queue did not provide it. The rebuilt
previous-main M10 reducer passed 9/10 and failed only
`queue_to_dynamic_runtime_kind`; the destination-typed branch passed 10/10 at
that checkpoint.

### Explicit casts

Clause 6.24.1 says that an assignment-compatible explicit cast returns the
value a variable of the cast type would hold after assignment. If the
expression is not assignment compatible and the cast type is a bit-stream
type, 6.24.1 instead directs the operation to 6.24.3.

Clause 6.24.3 defines bit-stream types recursively from integral, packed, and
string types; unpacked arrays, structures, and classes of those types; and
dynamically sized arrays (dynamic, associative, or queues) of those types.
Index zero of a dynamic
array or queue occupies the MSBs of its packed representation. Associative
arrays and classes are illegal destinations; a class with inaccessible
local/protected state is not a general source except for the current instance
`this`. When a dynamically sized source
or destination produces a size mismatch, the mismatch is an error as soon as
it can be determined.

The implemented strict carrier in this increment is intentionally smaller
than that recursive universe. It covers positional queue/dynamic-array values
whose elements are packed `bit`/`logic` vectors. Their widths may differ when
the complete source bit count divides exactly into the destination element
width. The tested byte-queue to word-dynamic-array round trip observes
index-zero/MSB order. A partial target element, a result that exceeds a bounded
queue, or the existing bounded runtime-width guard fails with a nonzero status
and an empty result instead of using ordinary stream padding or queue
truncation. General aggregate/class/structure bit-stream casts still use
legacy paths and are not claimed here.

### Bounded queues

Clause 7.10.5 says that an ordinary write to a bounded queue behaves as an
unbounded write followed by discarding elements beyond the declared bound and
issuing a warning. The destination-typed assignment/copy paths retain that
bound. A strict 6.24.3 cast cannot reuse truncation to hide a size mismatch.

The strict cast text encoding carries the queue maximum as a 64-bit value, and
the permanent test uses a bound above `UINT_MAX` to prove it does not wrap.
Several older ordinary queue signal and method opcodes still pass a maximum as
`unsigned`; this increment does not claim general support for queue bounds
above `UINT_MAX`.

### Subroutine output and empty calls

Clause 13.5 requires input values to be passed into a call and output/inout
values to be copied to their actuals on return. Output and inout actuals must
be procedural-assignment lvalues. Clause 13.3.2 gives automatic task output
formals their declared default on each entry and makes static task ports retain
their values between calls; 13.4.2 applies the corresponding lifetime model to
functions. An empty native body therefore cannot erase argument evaluation,
call-frame or dynamic-dispatch behavior, default output storage, or copy-back.

Previously, the generic open-array workaround copied native task output
queues/dynamic arrays in from the actual. That made automatic outputs observe
caller data instead of an empty default and made static outputs alias or lose
their retained formal value. A separate early return elided most calls whose
body was empty, suppressing input side effects and untouched-output copy-back.
Function output/inout checks also treated actuals only as rvalues in places,
allowing an invalid lvalue or an element-type mismatch to reach lowering.

The caller-shape copy-in remains only for imported DPI open-array output
formals, because foreign code needs the actual's descriptor before it can use
the open-array accessors. The project's DPI queue/dynamic-array output
acceptance remains an interoperability exercise at the Annex-H boundary, not
the normative basis for the native 13.3/13.4/13.5 lifetime result.

## Implementation

### Shared frontend compatibility

`positional_container_type_match` is the common queue/dynamic-array element
comparison used by casts and task/function copy boundaries. It excludes the
internal associative-array carrier and compares complete element components,
including nested associative key type and wildcard state. A ternary-aware
form validates both conditional arms. Only the outermost dimension receives
7.6's weaker kind comparison. A controlled concatenation-splice flag reapplies
that comparison at the destination element boundary; it cannot weaken a
direct whole-container assignment or subroutine actual.

Task and nonvoid-function output/inout actuals are elaborated as lvalues and
validated in the correct formal-to-actual copy direction. A pure output is
type-checked without evaluating the caller's value. An input/inout copy-in
error suppresses its dependent copy-back check, preventing duplicate
diagnostics without concealing the first error.

`PECastType` now retains a typed internal marker for positional-container
casts. Equivalent-element casts use `$ivl_container_cast`; the supported
non-equivalent integral bit-stream pair uses `$ivl_stream$cast$r$1`. A cast
diagnostic is emitted once even if width and typed elaboration visit the parse
expression separately. Conditional sources keep both arm types visible. Legal
recursive bit-stream pairs outside the integral carrier are deliberately sent
back to the pre-existing general cast path rather than being claimed by the
new opcode.

The narrow OpenTitan compatibility admission remains local to ordinary
`PAssign`. It accepts only a bare direct-identifier source, a queue/dynamic-
array kind change, non-enum packed `bit`/`logic` elements of equal nonzero
width and signedness, and a 2-state/4-state difference. It does not alter
global type compatibility or initializer, delayed/nonblocking, cast, formal,
or ref contexts.

### Destination-typed VVP lowering

The target compares the expression's source kind with the receiving declared
type and materializes the receiver before storage. The same conversion helper
is used for direct signals, class properties, selected and nested properties,
conditionals, user-function results, subroutine arguments and copy-back,
assignment patterns, queue methods, aggregate members, and object-collection
splices.

`%queue/to/darray` retains its legacy name and now accepts either positional
runtime source kind. `%container/to/queue` performs the inverse and applies the
target maximum. Real, string, vector, and object encodings are destination
typed. `b`/`sb` vector targets perform the 6.11.2 X/Z-to-zero conversion;
`v`/`sv` preserve four-state data; signed extension uses the source sign bit.
Nested container and unpacked-struct values copy independently while class
elements remain shared handles. Passive metadata and random state follow the
value, and an unpacked-struct destination prototype overrides a source
prototype where required.

Native container output formals are no longer evaluated in the copy-in pass.
An automatic queue formal receives a new empty queue; an automatic dynamic
array receives its null/empty default; a static formal is left untouched.
Return copy-back duplicates or converts the formal into the actual's declared
kind before signal, property, associative member, positional member, or fixed
property-slot storage. For a descending fixed property, an ordinary dynamic
source is traversed from its logical left edge while an already materialized
fixed view retains canonical numeric storage. Calls with empty bodies always
keep this protocol.

### Strict cast and loader contract

The stream-to-container text encoding now accepts a `!` strict-cast marker and
an optional 64-bit queue maximum. Strict execution checks divisibility and the
complete bounded result before constructing elements. Ordinary streaming
concatenation retains its prior padding/truncation behavior.

Typed object splices with an unpacked-struct prototype use an out-of-line
`vvp_container_opcode_data_s`. This leaves the common `vvp_code_s` at three
machine words, measured as 24 bytes on ARM64. Code-space cleanup owns the new
descriptor and its string. The VVP loader validates exact operand count,
element and stream encodings, numeric maximum, and resolved prototype kind
before scheduling. Runtime backstops do not assert, preserve their documented
object-stack balance, and terminate malformed internally constructed records
with a nonzero status.

### Direct fixed-array slice function actuals

The follow-on audit found that the value-returning function path still sent a
fixed unpacked-array slice through scalar rvalue elaboration. The task/void
path already had a private slice decoder and per-word copy loops, but
duplicating that strategy would leave DPI geometry, native fixed formals,
copyback, and target APIs with different representations.

`NetEArraySlice` is now the shared semantic value for a direct constant
one-dimensional slice. It records the backing signal, canonical low word,
element count, and selected left/right bounds. Target scans use only the
selected word nexuses. The DLL API exposes the same data without encoding it
as a scalar select. `tgt-vvp` lowers it through `%slice/push` followed by a
bounded `%load/arr/dar/slice`; output/inout copyback uses the corresponding
bounded store. The store validates the entire destination window and source
size before its first write.

Native function formals retain ordinary 7.6 left-to-right correspondence,
including opposite formal/actual directions. Pure fixed outputs are not
copied in: automatic storage begins at its declared default and static formal
storage retains its previous value. Fixed formal/actual shape and leaf type
are checked during elaboration. A slice written opposite to its own backing
array direction remains illegal; only the formal's direction may differ.

For imported DPI functions, the materialized object retains the slice's
declared bounds and is activated as a numeric-indexed open-array view. The C
regression checks every geometry accessor, input and inout values, output and
inout writes, and out-of-range rejection. It deliberately never reads an
output element before writing it because Annex H leaves that initial value
undetermined. The SV side proves inverse copyback and unchanged neighbors.
Multidimensional and class/property slice actuals, and `ref` slice formals,
remain explicit residuals.

## Permanent regression matrix

The paired 2017/2023 sources and direct VVP fixtures cover:

- equivalent-element assignment and input/output/inout transfer in both
  queue/dynamic-array directions, including the caller's destination kind;
- direct, property, selected, conditional, function-return, builder, nested-
  container, associative-value, and unpacked-struct destinations;
- independent container/struct values, retained class-handle identity,
  unpacked-struct prototypes, passive metadata, and one-time selector
  evaluation;
- same-kind and cross-kind assignment-compatible explicit casts, a direct
  method on the cast temporary, conditional cast arms, nested associative
  element metadata, and stable negative diagnostics;
- byte/word integral bit-stream casts, MSB ordering, strict size and bounded-
  queue failures, and a direct cast bound above `UINT_MAX`;
- ordinary 7.10.5 truncation/warnings through assignment, formal, aggregate,
  nested, and associative contexts, plus a fitting bound on a compatible cast;
- automatic output defaults, retained static output storage, inout copy-in,
  explicit automatic locals in a static task, empty-task input side effects,
  untouched output copy-back, and explicit allocation before a dynamic output
  copies left-to-right into a descending fixed member;
- task and function input/output/inout rejection when a queue/dynamic kind
  differs in a faster-varying dimension, plus a legal outer-kind control; and
- malformed VVP arity, element/stream encodings, prototype descriptors, and
  the strict runtime-width failure without a signal termination.

The final full checkpoint plus the focused evidence is:

| Gate | Result |
|---|---:|
| Chapter-7 focused legacy | **79/79** |
| Chapter-7 focused JSON/VVP | **72 ran, 0 failed** |
| Direct container conversion/runtime/parser invariants | **42/42** |
| Negative diagnostics | **136/136** |
| Full legacy SystemVerilog | **2,151/2,151** |
| Full JSON/VVP | **1,229 ran, 0 failed** |
| VPI | **103/103** |
| Canonical real-DPI UVM | **354/354, 0 failed, 0 skipped** |
| Fixed-slice focused legacy | **24/24** |
| Fixed-slice focused JSON/VVP | **21 ran, 0 failed** |
| Real-DPI fixed-slice reducer | **1/1** |
| Hand-written slice-opcode recovery invariants | **7/7** |

The complete canonical real-DPI UVM suite completed in 664.82 seconds wall
time using the worktree-local compiler and VVP runtime. It loaded the real DPI
umbrella; no `UVM_NO_DPI` fallback was used.

## OpenTitan application evidence

The original application symptom was
`spi_agent_cfg::swap_byte_order` assigning between `logic [7:0][$]` and
`bit [7:0][]`. Those element types are not equivalent under 6.22.2, so the
accepted source spelling is explicitly an interoperability extension rather
than 7.6 conformance. Slang 11.0.448+e222e7dc0 rejects the four paired
state-changing assignments under `--std=1800-2017`, `--std=1800-2023`, and
`--std=1800-2023 --compat=vcs`. No VCS, Questa, or Xcelium executable was
available for a direct commercial differential.

An authentic targeted replay, gathered before the later cast and subroutine
hardening, covered four unmodified UVM compile targets:

| Target | Current old-diagnostic count | Current first independent frontier |
|---|---|---|
| `lowrisc:dv:spi_device_sim:0.1` | 0 | `spi_device_scoreboard.sv:1177` syntax |
| `lowrisc:dv:spi_host_sim:1.0` | 0 | `spi_host_env_cfg.sv:36` syntax |
| `lowrisc:dv:top_darjeeling_chip_sim:0.1` | 0 | `spi_host_driver.sv:40` compound class-property event expression |
| `lowrisc:dv:top_earlgrey_chip_sim:0.1` | 0 | `spi_host_driver.sv:40` compound class-property event expression |

All four remain **FAIL**. Recorded historical red counterparts prove removal
of the mismatch for the Darjeeling and Earlgrey top-chip closures. The older
standalone `spi_device_sim` and `spi_host_sim` evidence stopped at
`spi_device_scoreboard.sv:1177` and `spi_host_env_cfg.sv:36`, respectively, and
does not prove that diagnostic was formerly reached in those targets. The
current four-target replay therefore proves absence in all four, but a
red-to-green transition only for the two top-chip closures. It exposes later
independent frontiers; it does not make an IP, top, or OpenTitan-wide pass
claim. No fresh full 61-target OpenTitan census and no Caliptra replay were run
for the final commit.

## Known boundaries and next work

- General recursive aggregate/class/structure bit-stream casts remain on
  legacy lowering paths; only the integral positional-container carrier is
  closed here.
- Direct strict cast materialization preserves a queue maximum above
  `UINT_MAX`, but ordinary queue signal/method storage still has unsigned-
  maximum paths.
- The mixed-state OpenTitan interoperability extension accepts only an
  ordinary blocking assignment with a bare direct-identifier source. Selected,
  scoped, property, nested, and function-return sources remain strict.
- DPI queue/dynamic-array output behavior remains an interoperability area and
  is not used to broaden the native SystemVerilog conformance claim.
- A fresh full OpenTitan matrix and Caliptra application replay remain to be
  gathered after this compiler checkpoint; the compiler's full local legacy,
  JSON/VVP, negative, VPI, and canonical real-DPI UVM gates are complete.

Full IEEE 1800 clauses 6, 7, and 13, full OpenTitan and Caliptra DV/runtime
flows, SVA/formal-source elaboration, and commercial-simulator parity remain
open project goals.

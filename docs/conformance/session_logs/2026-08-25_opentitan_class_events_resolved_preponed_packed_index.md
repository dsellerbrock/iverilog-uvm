# OpenTitan class events, resolved Preponed history, packed indices, and commercial fixed-array DPI (2026-08-25)

## Scope and provenance

This increment was developed from Icarus commit
`92c68dd3c0b8bb0478ec9b6de77f8645ad16c180` and replayed against the
unchanged OpenTitan HMAC graph generated from revision
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`. OpenTitan sources were not
modified. The graph was generated through OpenTitan's regtool/reggen and
FuseSoC flow with native arm64 Python 3.13.15 and FuseSoC 2.4.5. The compiler,
VVP runtime, DPI-export stub, and `cryptoc_dpi` DPI bundle were all rebuilt for
Apple Silicon. DPI ABI decisions in this increment target IEEE 1800-2017 Annex
H compatibility with VCS, Questa, and Xcelium. Verilator is not used as the
fixed-array ABI oracle.

## Class-property event controls

The HMAC scoreboard waits for a property reached through a run-time selected
associative-array element:

```systemverilog
wait(cfg.m_alert_agent_cfgs[cfg.list_of_alerts[i]].alert_init_done == 1);
```

The old event lowering watched an object as a whole. An unrelated property
write, including a same-value write, could wake the waiter and let a
zero-time `fork ... join_none` loop allocate without bound. The replacement
records the selected owner expression and terminal property, fixed-array word,
and optional packed bit. The owner is evaluated once when the wait arms. VVP
keys the waiter by that exact mutation identity, retains the owner object for
the wait lifetime, suppresses same-value writes, and unlinks the waiter on
normal wake, disable, reap, or object destruction.

Permanent coverage consists of ten direct event/wait and boundary tests plus
two OpenTitan-shaped associative-owner tests in both legacy and JSON/VVP
harnesses. The direct focus passes 10/10 and the nested focus passes 2/2 in
each harness. The direct focus also pins invalid/X selector parking and
cancellation, positive class-only compound event and wait forms, a mixed
ordinary/VIF-plus-property wait, and the exact diagnostic for the remaining
mixed one-shot event boundary.
The existing 17/17 property-container controls remain green.

This is a precise armed-owner subset, not handle-rebinding support. Replacing
the root or selected handle, deleting/rekeying the associative element, or
changing the key/index expression while the wait is armed is not itself an
event source. A later re-arm reevaluates the expression. A direct `@` accepts
a property, one property select, or one integral class-only compound
expression. The compound event records the expression's arm-time value and
filters mutation wakeups whose scheduled re-evaluation is unchanged. A change
and restoration of the complete compound expression before the scheduled
waiter runs can still be missed; closing that same-time transaction boundary
requires a synchronous runtime expression recipe. A one-shot mutation event
mixed with an ordinary/named/VIF event remains loud. Class-only compound
`wait` expressions re-evaluate, while a mixed ordinary/VIF-plus-property wait
uses isolated waiter branches, `join_any`, and cancellation of the losing
branch before the outer condition is re-evaluated. Automatic activation
operands are treated as stable snapshots (the UVM state/count idiom).
Function-return, dynamic-interface, and static-container owner shapes remain
unclaimed or loud.

## Preponed reads of resolved strength nets

OpenTitan's TL-UL assertion operands include resolved aliases represented by
VVP `vec8` nets. `%hist/on` previously enabled history only for ordinary
`vec4` signals, so `%load/preponed` silently read the live resolved value after
a same-slot Active update. That produced a false `respMustHaveReq_A` failure.

`vvp_wire_vec8` now snapshots the complete strength vector once per time slot
before a driven update. `%hist/on` enables this history, and
`%load/preponed` reduces the saved strength vector to vec4 only when it is
loaded. Force overlays are intentionally not added to driven history, matching
the existing vec4 contract. The strength-net reducer is red against the old
runtime and green in both permanent harnesses. The broader Caliptra/OpenTitan
Preponed focus passes 57/57 legacy and 16/16 JSON/VVP.

## Run-time select into a singleton packed dimension

With the first two fixes, the unchanged HMAC smoke exposed a status mismatch:
the scoreboard expected FIFO depth one while RTL reported zero. A hierarchy
probe showed that every accepted TL request still carried masks such as `4'hf`
or `4'hc`, but the adapter's expanded 32-bit mask remained zero. The relevant
unchanged RTL is:

```systemverilog
logic [WidthMult-1:0][31:0] wmask_int;
wmask_int[woffset][8*i +: 8] = {8{tl_i_int.a_mask[i]}};
```

For HMAC, `WidthMult` is one. `collapse_dims_exprs()` passed the 32-bit inner
stride to element-index normalization. The outer `[0:0]` range was therefore
mistaken for a descending indexed part select, and generated VVP calculated
`(woffset - 31) * 32 + 8*i`. Every store was out of range and was correctly
discarded by VVP.

Each packed-dimension component is now normalized as a one-element select and
the existing inner-slice width is applied afterward as its stride. The
permanent reducer covers singleton, ascending, and descending outer packed
dimensions with run-time outer indices and run-time `+:`/`-:` inner bases.
Against the old compiler its singleton write stayed zero and its read returned
X; with the fix it passes and the erroneous `%subi 31` is absent. The packed
focus passes 2/2 legacy and 1/1 JSON/VVP.

## Commercial fixed-array DPI ABI

Annex H makes a distinction that is easy to hide behind one simulator's
adapter: an unsized/open array formal is passed as an `svOpenArrayHandle`, but
a sized fixed unpacked-array formal is passed as a direct C pointer. Output
and inout fixed formals do not add another pointer level. OpenTitan's exact
SHA-384 import combines both forms: the byte-message open array is a handle,
while `output int unsigned hash[12]` is a direct pointer. Its emitted internal
signature is `xul+O`: lower-case `x` denotes the open packed array and upper-
case `O` the direct fixed atom array.

The old runtime treated the uppercase fixed case like the lowercase handle
case. The SHA-384 C model returned after writing descriptor/scratch storage,
leaving the SV hash array at zero. Fixed arguments now have distinct direct
paths for atom/real (`O`), scalar `svBit`/`svLogic` (`B`/`G`), and packed
canonical `svBitVecVal`/`svLogicVecVal` (`X`/`Y`) elements. These letters are
internal VVP metadata; the external C ABI is the standard Annex H type. `B`
normalizes every two-state scalar byte to 0 or 1. `G` uses the canonical
`svLogic` values 0, 1, Z=2, and X=3. Both use call-scoped storage and copy
output/inout changes back. An explicitly packed `[0:0]` element remains an
`svBitVecVal`/`svLogicVecVal`, so equal SV width does not collapse distinct C
types.

A multidimensional sized formal cannot use the nested object tree needed by
open-array accessors: that tree has geometry but no one contiguous leaf
pointer. The direct path instead exposes VVP's existing flat fixed-signal
storage. C order is numeric-low-first in every dimension with the rightmost
dimension varying fastest. Before that pointer is formed, SystemVerilog
argument copy-in maps actual declared left to formal declared left in every
dimension; output/inout copyback applies the inverse mapping. A permanent
opposite-direction two-dimensional test prevents this from degenerating into
an incorrect flat `memcpy`.

The VVP array element descriptor formerly carried only eight width bits, so a
256-bit element collided with the real/type encoding and a 384-bit element
truncated to 128 bits. The extension retains the existing flag positions in
bits 8 through 13 and stores the upper width bits in previously unused bits.
Old images, whose extension bits are zero, therefore decode unchanged. The
new focus value-checks complete `bit[255:0]` and `logic[383:0]` elements,
including high-word and X/Z copyback.

The REAL-DPI focus passes 12/12:

- fixed-array marshal, descending-int, fixed-packed, open-array copy API,
  output-open-array, and packed-queue pointer controls;
- the exact OpenTitan SHA-384 signature; and
- scalar, integer/time, multidimensional, opposite-direction
  multidimensional, and wide-element fixed ABI regressions.

In a fresh compile and unchanged-HMAC replay, the repaired ABI reached
218,117,052 ps and began sequence 5/33 before the 45-second CPU guard. It
completed two digest predictions and two digest reads with zero UVM errors,
fatals, assertions, or crashes. The randomized smoke permits up to 50
iterations, so this is focused proof that the prior digest blocker is gone,
not a complete smoke verdict.
The initial seven-case ABI-focus output and the bounded HMAC output are
retained under `evidence/dpi-commercial-abi-arm64-20260825/` and
`evidence/opentitan-hmac-class-event-after233-arm64-20260825/`; the five new
permanent fixed-array reducers extend the recorded focus result to 12/12.

## Unchanged HMAC replay and current frontier

The nested property wait now completes and the real sequence starts. Resolved
Preponed sampling removes the former TL-UL assertion. The packed-index probe
then proves the FIFO symptom was a compiler miscompile rather than a scoreboard
or OpenTitan defect.

The freshly rebuilt unchanged image no longer follows the artificially empty
FIFO path: it performs real SHA/FIFO work and is consequently much slower. A
subsequent compiler fix split mixed ordinary/VIF-plus-property waits into
cancellable waiter branches; this matches the alert and TL monitor forms used
by the unchanged graph. Under the campaign's 45-second per-process CPU guard
the exact rebuilt image reached 3,412,009,286 ps, about 87 times beyond the
former 39,220,884 ps blocker, with no UVM error, fatal, assertion failure,
crash, or zero-time stall before the guard stopped it. This is a bounded
frontier result rather than a clean HMAC pass, and no claim is made that this
is the last OpenTitan runtime frontier.

## Broad validation

The native arm64 build passes `make -j1 check`. The complete legacy harness
reports 4,077 cases: 4,072 passes, zero unexpected failures, two inherited
VHDL not-implemented cases, and the three recorded expected-fail controls.
The complete JSON/VVP harness passes 962/962, bundled VPI passes 100/100, and
the exact-diagnostic negative suite passes 123/123. The supported REAL-DPI
group passes 32/32 with zero skips, including the fixed-array 12/12 focus. The
UVM runner must select the branch-local installation.

## Invocation gotchas

- Run `matrix-iverilog.scr` from its FuseSoC-generated work directory because
  its include and source paths are relative.
- Use `-g2012 -stb -uvm` with OpenTitan's `UVM`, register-width,
  `SIMULATION`, and `DUT_HIER=tb.dut` defines.
- Rebuild the generated DPI-export C stub and all `cryptoc_dpi` objects as
  Mach-O arm64 whenever the VVP image changes.
- Load pure DPI bundles, including the rebuilt `cryptoc_dpi` bundle, with
  `vvp -d bundle.vpi`. The `.vpi` filename suffix does not make it a VPI
  startup module. `-M/-m` is the VPI loader and correctly rejects a pure DPI
  library that has no `vlog_startup_routines`; changing the library to satisfy
  `-m` would be the wrong fix.
- Select both the test and sequence for this generated HMAC graph:
  `+UVM_TESTNAME=hmac_base_test +UVM_TEST_SEQ=hmac_smoke_vseq`. Omitting the
  first produces `NOCOMP`; omitting the second produces a sequence-factory
  fatal before the compiler frontier is exercised.
- Prepend this worktree's `local-install/bin` when invoking
  `.github/uvm_test.sh`. Without that, `which iverilog` and the adjacent
  `iverilog-vpi` can select a stock Homebrew installation; the resulting UVM
  compile/DPI errors are a tool-selection failure, not a regression verdict.
- Use simulated timestamps or `IVL_TIME_TRACE_NS` to measure progress. Quiet
  UVM output and wall time do not establish a hang or a passed frontier.
- The shared resource runner retains a 45-second CPU guard and has no RSS
  ceiling. A CPU-guard exit is not a test verdict.

Evidence is retained in
`evidence/opentitan-hmac-class-event-after233-arm64-20260825/`.

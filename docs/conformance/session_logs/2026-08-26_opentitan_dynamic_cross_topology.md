# 2026-08-26 — OpenTitan dynamic cross topology

## Scope and provenance

- Worktree: `iverilog-uvm-opentitan-dynamic-cross-after238-arm64-20260826`
- Branch: `agent/opentitan-dynamic-cross-after238-arm64-20260826`
- Base: `origin/main` at
  `1e4df2813c1200b8cadfe6a9a3e28cb3451dadab` (PR #238 merge)
- Host: native Apple Silicon; compiler, VVP, Python, and corpus tools are ARM64
- OpenTitan: clean `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`
- Standards: local ignored IEEE 1800-2017 and IEEE 1800-2023 PDFs, especially
  19.3, 19.5, 19.5.1–19.5.7, 19.6, 19.6.1–19.6.1.4, 19.7 Tables 19-1 and
  19-2, and 19.10. The retention delta is 2017 19.6.1 p.572 and Table 19-1
  pp.578–579 versus 2023 19.6.1 p.600, Tables 19-1/19-2 pp.606/608, and the
  option structures on pp.613–614; it is not a 19.6.1.1 rule.

This increment implements the bounded dynamic-family cross forms exposed by
unchanged OpenTitan sources. It does not claim complete clause 19, a clean
OpenTitan application, or full Caliptra DV runtime. Current local UVM and the
final static Caliptra differential are recorded below.

## Original failure and corpus frontier

PR #238 made OpenTitan's constructor-dependent coverpoint range compile, but
the next compiler path dropped any cross containing that dynamic bin family:

```text
sorry: cross '...' contains a constructor-dependent bin family that cannot
yet be represented in cross metadata; the cross is dropped.
```

The audit found 20 OpenTitan UVM targets containing the diagnostic. Sixteen
had it as a first hard coverage frontier; the common CIP covergroups accounted
for 48 emitted sites, mailbox coverage added three, and I2C SCL coverage added
one. The smallest exact unchanged replay was `soc_dbg_ctrl` at 358 source
files and roughly 2.1 MiB.

## Audited semantics

The implementation and permanent tests use these IEEE rules:

- Covergroup bin and cross topology is frozen for each constructed covergroup
  object; a constructor-dependent family may therefore have a different
  cardinality in two instances of the same covergroup type.
- An integral open array bin (`bins b[]`) is keyed by distinct resolved value.
  Duplicate and overlapping ranges coalesce, with value-derived bin names.
- A fixed array (`bins b[N]`) partitions the ordered matching occurrences.
  With `B = max(floor(M/N), 1)`, bins before the final nonempty bin receive `B`
  occurrences while values remain and the final bin receives the remainder.
- Ignore/illegal values are removed after fixed distribution, without
  redistributing survivors. Empty bins do not enter the denominator.
- One sample may match more than one source-bin identity. A cross therefore
  evaluates the Cartesian product of every matched identity in each dimension.
- Different overlapping named normal cross bins may all count, but each named
  bin counts at most once per sample. Precedence is `illegal` over `ignore`
  over normal independent of declaration order.
- An illegal cross match belongs to that cross. It must not suppress the
  contributing coverpoint counts or unrelated crosses.
- IEEE 1800-2017 retains uncovered automatic cross bins. IEEE 1800-2023
  `option.cross_retain_auto_bins` defaults to 1. A covergroup assignment is the
  default for its crosses and a cross-local assignment overrides it; it is not
  a coverpoint option or any `type_option`. With a value of zero, any explicit
  normal, ignore, or illegal cross-bin declaration removes all automatic bins,
  even when the selection is empty. With no explicit bin, automatic bins
  remain. Option assignments are evaluated for each constructed covergroup
  instance by 19.7.

## Design

The elaborator no longer chooses one constructor value and builds type-global
cross counters from it. Instead it emits three bounded metadata records:

- `.covgrp_cross` identifies the cross item, dimensions, and constant automatic-
  bin retention policy;
- `.covgrp_cross_term` identifies a fixed counter, dynamic family, transition
  counter, or logical transition-family member for each dimension; and
- `.covgrp_cross_bin` carries a normal/ignore/illegal target plus a compact
  postfix selection plan.

The target API, DLL export table, VVP emitter, loader, class metadata, and raw
metadata validation all carry those records. Existing images without the new
records remain loadable, while out-of-range fields and invalid record kinds are
rejected before runtime use.

VVP resolves the source families after constructor values and the enclosing
object link are available. It builds an object-owned dimension/route cache and
invalidates it if the underlying dynamic-family cache changes. Sampling then
matches fixed, transition, and dynamic logical choices, deduplicates named and
automatic hits, and updates per-instance counters. The verified selector
surface covers automatic products, `binsof(cp)`, `binsof(cp.bin)`, fixed or
constructor-resolved `intersect`, conjunction, overlapping named bins, and
cross `iff`. The selection IR can encode additional Boolean operators, but
broader dynamic combinations are not claimed by this checkpoint.

The fixed elaboration path was corrected at the same semantic boundary:
open-bin values now coalesce, fixed-bin remainders go to the final bin,
ignore/illegal carving happens after fixed distribution, and named cross-bin
routing resolves all matches before applying `illegal` > `ignore` > normal.
Illegal cross records no longer mark their source coverpoints suppressed.

`cross_retain_auto_bins` is edition-gated through the central edition feature
table. The implemented 2023 subset uses constant covergroup defaults and
cross-local values; coverpoint and `type_option` placements are errors, and
`-g2017` rejects the declaration. Constructor/per-instance nonconstant
expressions remain unsupported. One sentence on 2023 p.607 says “covergroup or
coverpoint definition,” but Table 19-2 and the 19.10 implicit structures
consistently say covergroup and cross, with no coverpoint member; this is
treated as an apparent editorial typo.

## Permanent tests

The paired focus lists contain 20 legacy and 20 JSON/VVP entries across
`-g2017` and `-g2023`. In addition to the eight typed-constructor entries from
PR #238, this increment adds paired coverage for:

- `sv_covergroup_array_bin_identity`: static/dynamic open-bin coalescing and
  fixed-array duplicate/remainder identity;
- `sv_covergroup_fixed_bin_post_carve`: distribution before ignore carving;
- `sv_covergroup_dynamic_cross`: different per-instance automatic-product
  cardinalities and independent counters;
- `sv_covergroup_dynamic_cross_binsof`: OpenTitan CIP and I2C-shaped named
  selection, unconstrained dynamic dimensions, overlap, and `iff`;
- `sv_covergroup_cross_bin_precedence`: overlapping normal bins, declaration-
  order-independent special-bin precedence, and illegal-cross locality; and
- `sv_covergroup_cross_retain_auto_bins_2023` plus the 2017 negative: fixed and
  dynamic constant retention behavior and the edition boundary.

The retention reducer directly covers an ordinary explicit bin, a
no-explicit-bin control, inherited covergroup defaults on fixed and dynamic
crosses, cross-local disable and enable overrides, and empty ignore/illegal
declaration presence. Procedural-write and repeated-assignment cases are not
yet permanent evidence.

The malformed raw-VVP test adds narrowing, shape, and kind checks for all three
new metadata records.

## Validation

A serial timing sample taken before the final option-scope and metadata
hardening recorded `make check` at 2.65 seconds, the legacy corpus at 112.72
seconds, JSON/VVP at 20.71 seconds, negative diagnostics at 2.45 seconds, and
bundled VPI at 31.14 seconds. Those timings are retained as performance
evidence only; the definitive post-hardening counts appear below.

The final OpenTitan 61-target UVM compile matrix completed in 47.62 seconds:

- before: **1 DEBT / 57 FAIL / 3 SETUP_FAIL / 0 PASS**;
- after: **8 DEBT / 50 FAIL / 3 SETUP_FAIL / 0 PASS**;
- transitions: seven FAIL→DEBT (`adc_ctrl`, `dma`, `hmac`, `mbx`, `pattgen`,
  `soc_dbg_ctrl`, and `uart`), while `tl_agent` remains DEBT;
- exact former constructor-dependent-cross-drop diagnostics: **0**;
- generic cross-drop diagnostics: **0**; and
- timeouts or resource-limit signals: **0**.

The remaining 50 failures and three setup failures are not cross successes;
they retain independent parser, provider, clocking, dynamic-`with`, generated-
graph, and isolated elaboration frontiers. The matrix compiled images but did
not execute the simulations, so it contains no clean application or runtime
pass.

Canonical evidence:

```text
/Users/danielellerbrock/projects/iverilog_uvm/evidence/opentitan-dynamic-cross-final-after238-arm64-20260826T183204-0600/matrix
```

The result JSON SHA-256 is
`b97844e5b327b98a251e3c03f15e6939e827c0f849a88cfd538f1334b388fa55`.
The compiler-engine SHA-256 is
`599a85f0c35730e151227abfd6c698cf9bc8556c50f8f6b70ccf0aa728e1cff1`.

After the final local hardening, the definitive local gates are:

- focused legacy: **20/20**;
- focused JSON/VVP: **20/20**;
- full legacy: **4,103 pass / 0 fail / 2 NI / 3 expected fail**
  (**4,108 total**);
- full JSON/VVP: **993/993**;
- negative diagnostics: **136/136**;
- bundled VPI: **103/103**; and
- canonical unmodified real-DPI UVM: **354/354**.

The VVP grammar retains the parent's **14 shift/reduce and 5 reduce/reduce
conflicts across 9 states**. After normalizing state and rule numbers, the
conflict-descriptor profile is unchanged; both profiles have SHA-256
`f9d4b8ef1d5ab7f29b5ca7ae9bce2ac780960055409d4b6ff3f47e3dcacf978d`.

The final frozen Caliptra static census completed 105 jobs across four serial
lanes, 420 compiler invocations, in 52.33 seconds wall:

- Icarus with assertions: **53/105**;
- Icarus without assertions: **53/105**;
- Icarus synthesis: **53/105**;
- Slang: **54/105**; and
- classifications: **52 PASS / 1 DEBT / 51 SHARED_SOURCE_OR_CONFIG /
  1 SOURCE_ORDER_DEBT / 0 ICARUS_GAP**.

The sole Slang advantage is the known `csrng_raw_wrap` source-order debt. This
is compile/elaboration/synthesis differential evidence, not full Caliptra DV
runtime. Evidence is outside the repository at
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/caliptra-dynamic-cross-final-after238-arm64-20260827T003032Z`;
the result JSON SHA-256 is
`857e7b5a97ca35810ac21258e0367f63bd53766ee5d3ca2f65639e09e8add9fd`.

## Native-toolchain and invocation gotchas

- Prepend Homebrew Bison to `PATH` before regenerating or building:
  `/opt/homebrew/opt/bison/bin`. macOS `/usr/bin/bison` is 2.3 and rejects the
  typed destructor used by `parse.y`; the working Homebrew Bison is native
  ARM64 3.8.2.

  ```sh
  NATIVE_PATH=/opt/homebrew/opt/bison/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
  RESOURCE_RUNNER=/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/resource-runner
  "$RESOURCE_RUNNER" env PATH="$NATIVE_PATH" make -j4
  "$RESOURCE_RUNNER" env PATH="$NATIVE_PATH" make install
  ```

- Use the OpenTitan Python 3.13 environment explicitly:
  `evidence/arm64-tooling/opentitan-python313/bin/python3` and its sibling
  `fusesoc`. The matrix records Python 3.13.15, FuseSoC 2.4.5, and the real
  Homebrew ARM64 interpreter. The shell's default Python is not a substitute.
- Generate the supported OpenTitan graph through its register/core generation
  and FuseSoC flow. Do not invent a flat file list or modify the corpus.
- `tgt-fpga` is listed in the top-level Makefile's optional `NOTUSED` targets,
  but two JSON entries invoke `-tfpga`. Build and install it explicitly with
  the configured `tgt-fpga/Makefile`; the installed `fpga.tgt` must be native
  ARM64. Without it the JSON run reports two setup failures rather than the
  verified 993/993 compiler result.

  ```sh
  "$RESOURCE_RUNNER" env PATH="$NATIVE_PATH" make -C tgt-fpga -j4
  "$RESOURCE_RUNNER" env PATH="$NATIVE_PATH" make -C tgt-fpga install
  ```

- The resource runner is `evidence/arm64-tooling/resource-runner`; this
  checkpoint uses a 45-second CPU guard per compiler/runtime invocation and no
  RSS cap. A CPU-guard result is not automatically a hang.

## Explicit limits and next gates

This increment deliberately retains loud bounded limits:

- a constructor/per-instance expression for `cross_retain_auto_bins` is not
  represented; only the verified constant 2023 value is supported;
- an illegal named cross bin over a transition term disables that dynamic
  cross plan with a diagnostic;
- remaining dynamic `with`, `matches`, set-expression, `CrossQueueType`, and
  broader compound-selector forms are open;
- ignore/illegal source values are not carved from a dynamic-family source
  denominator;
- type-coverage union, detailed reporting/VPI, complete normative naming,
  broader signed static range/intersect normalization, and empty trailing
  fixed-array-bin identity/naming remain open;
- cross topology and explicit open-bin materialization are capped at 65,536
  logical bins/products and reject larger forms loudly; and
- real/tolerance coverage remains future IEEE 1800-2023 work.

The next implementation frontiers are OpenTitan's remaining parser, provider,
clocking, and dynamic-selection failures. Full Caliptra DV runtime still
requires external verification inputs; the completed static census cannot
substitute for it. VCS, Questa, and Xcelium remain the commercial
interoperability targets after the selected IEEE text. Slang is a parser/
elaboration differential; Verilator is diagnostic only. This work
strengthens an eventual RTL/DV/formal-compatible frontend and simulation IR,
but no formal proof engine is claimed, and UPF/IEEE 1801 remains deferred.

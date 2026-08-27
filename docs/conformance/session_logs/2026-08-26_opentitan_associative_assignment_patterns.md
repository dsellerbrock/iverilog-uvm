# OpenTitan associative-array assignment patterns — 2026-08-26

## Scope and provenance

This increment started from `origin/main` at
`a2ebad3b4a654d968da8c31454b408835e1591b1` (merged PR #239) on branch
`agent/opentitan-dynamic-with-after239-arm64-20260826`. OpenTitan remained at
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`; neither OpenTitan, Caliptra, nor
the Accellera UVM sources were modified.

The normative audit used the ignored local copies
`docs/standards/local/IEEE_Std_1800-2017.pdf` (SHA-256
`2b94a960a93c0bd2cf10305e6c05c57ba865e6fdcd20dcbbd42319f82177ce31`)
and `docs/standards/local/IEEE_Std_1800-2023.pdf` (SHA-256
`2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`).
The relevant rules are fixed-array indexing and invalid selectors in 7.4,
associative-array assignment patterns in 7.9.11, and assignment-pattern rules
in 10.9.1. The shared rules were checked in both selected editions and receive
paired `-g2017`/`-g2023` executable evidence.
The PDFs remain under the repository's ignored `docs/standards/local/`
directory and are not part of the Git change.

## Original application frontier

OpenTitan used nonempty associative-array literals in forms such as enum keys
mapping to strings, enum keys mapping to queues, string-keyed nested maps, and
fixed unpacked arrays whose selected slot is a string-keyed map. The frontend
accepted only the empty map and lone-default forms. Other legal patterns
stopped at syntax errors or the explicit
`nonempty associative-array assignment patterns ... are not yet supported`
diagnostic. Fixed-prefix signal storage also conflated the canonical fixed
word with a trailing associative key.

An eight-core PR #239 baseline compared with the corresponding entries in the
final full replay removes every former associative-literal syntax/refusal
diagnostic. The baseline-to-after hard-error movements were:

| OpenTitan core | PR #239 baseline | after this feature | Meaning |
|---|---:|---:|---|
| Darjeeling OTP | 26 | 25 | one literal blocker removed |
| CSRNG | 44 | 28 | eight assignment sites, two diagnostics each removed |
| EDN | 138 | 129 | former literal diagnostics absent; later recovery frontier reached |
| entropy_src | 207 | 197 | former literal diagnostics absent; later recovery frontier reached |
| lc_ctrl | 7 | 6 | enum-to-queue literal blocker removed |
| top Darjeeling | 1 | 4 | advanced past the literal into a later `for`-declaration parser frontier |
| top Earl Grey | 1 | 6 | advanced past the literal into later parser/bind frontiers |
| Earl Grey OTP | 23 | 22 | one literal blocker removed |

These are compile-frontier movements, not clean OpenTitan passes. A higher
post-feature error count on a top-level core means compilation reached and
reported later independent diagnostics that the original first stop hid.

## Audited semantics and implementation boundary

The implemented subset supports a fresh associative value containing explicit
constant string, integral, or enum keys and at most one `default`. Duplicate
keys after declared-index conversion, duplicate defaults, nonconstant keys,
X/Z integral keys, and incompatible key/value categories are errors. A
`default` installs fallback state and does not create an entry or affect
`size()`.

Pattern items are evaluated once in lexical order into a fresh typed builder.
The enclosing assignment replaces the destination only after the complete
right-hand side exists, so self-reference and side effects cannot observe a
partially replaced map. Whole maps, queues, nested maps, and unpacked-struct
values copy independently; class elements preserve class-handle identity.
Declaration initialization, procedural assignment, typed/cast patterns,
arguments, returns, conditional arms, and the exact OpenTitan value shapes use
the same contextual lowering.

The direct signal-backed fixed-unpacked-prefix subset retains the product of
all declared fixed dimensions as the outer object-array storage. It separates
that canonical word from a trailing associative key for whole-map
reads/writes, entry reads/writes, and map methods. Integral, string, and real
leaf values use the selected map receiver; the real reducer pins
explicit/default reads, direct stores, sibling isolation, and
constant/variable outer selectors. Ascending, descending, nonzero, negative,
and mixed multidimensional ranges map to independent slots. Every fixed
dimension is bounds-checked before flattening. An undefined or out-of-range
component therefore cannot alias a valid sibling: stores still evaluate their
address and RHS once but make no write, while reads and map methods cannot
touch the sibling either.

This is not complete clause-7 or clause-10 closure. The declaration admission
is intentionally limited to direct signal-backed fixed-unpacked prefixes
ending in an associative leaf whose value is integral, string, or real.
Packed bit/part/member and other deeper/partial entry tails, property/member
and struct-nested receivers, fixed-prefix queue/dynamic-array leaves,
fixed-prefix maps with class-handle/container/struct values, broader
receiver/context combinations, and associative-array-typed parameters remain
unsupported or loud. In particular, associative-array-typed parameters remain
a separate IEEE 1800-2023 candidate; this shared assignment-pattern work does
not implement them.

## Permanent evidence

The paired positive reducers cover:

- explicit/default construction with integral, string, real, class-handle,
  queue, nested-map, and unpacked-struct values;
- declaration, assignment, typed-pattern/cast, argument, return, and
  conditional contexts;
- lexical once-only evaluation, atomic replacement, default fallback without
  insertion, map size, value copying, and class-handle identity;
- the exact OpenTitan enum-to-string, enum-to-queue, nested-map, and
  fixed-prefix shapes; and
- one-dimensional nonzero/descending plus mixed-direction multidimensional
  fixed prefixes, real-valued explicit/default reads, direct entry assignment,
  every selected slot, and invalid-outer-index no-op behavior with retained
  side effects; and
- variable multidimensional OOB selectors that would flatten onto valid words
  without per-dimension checks, covering whole-map stores, entry stores and
  reads, and map-method receivers without sibling aliasing.

Paired negative reducers pin nonconstant and X/Z integral keys, duplicate
keys, duplicate defaults, incompatible enum/string key categories,
incompatible queue and class/integral values, and the deliberately loud
deeper/partial fixed-prefix entry boundary. A raw VVP fixture separately
verifies that malformed `%aa/set/default/v` metadata cannot use a width
mismatch to consume source stacks or resize a value to the malformed
instruction operand; the raw runner is part of `.github/ivtest_gate.sh`.

## Native ARM64 validation

All final invocations used the worktree-local post-audit compiler. The local
language/runtime gates are clean:

- paired associative-pattern focus: **54/54** in the legacy harness and
  **54/54** in JSON/VVP, including the audit-added 2023 struct-value twin,
  paired nonconstant/X/Z-key diagnostics, and paired real fixed-prefix case;
- malformed-default-setter raw VVP fixture: pass;
- `make check`: pass;
- canonical legacy ivtest: **4,127 pass, 0 fail, 2 NI, 3 expected fail**
  (**4,132 total**) in 115.27 seconds;
- canonical JSON/VVP: **1,017/1,017** in 21.06 seconds;
- negative diagnostics: **136/136**;
- bundled VPI: **103/103** in 29.04 seconds; and
- canonical unmodified real-DPI UVM: **354/354**, 0 failed, 0 skipped, in
  610.12 seconds. Both the start and final summary confirm the real DPI
  umbrella loaded without `UVM_NO_DPI`.

Homebrew Bison 3.8.2 reports the same grammar profiles for the current tree
and its exact `origin/main` parent. The main parser remains at 535
shift/reduce and 1,115 reduce/reduce conflicts across 201 states, normalized
descriptor SHA-256
`b96fa4bf669e73f14ed8748e864e8b3f4cdfbdc61b45ec6d5cab66a7e6946bc8`.
The VVP parser remains at 14 shift/reduce and 5 reduce/reduce conflicts across
9 states, with byte-identical raw reports and normalized descriptor SHA-256
`f9d4b8ef1d5ab7f29b5ca7ae9bce2ac780960055409d4b6ff3f47e3dcacf978d`.

The fresh full OpenTitan UVM compile census completed all 61 targets in 53.60
seconds with **8 DEBT / 50 FAIL / 3 SETUP_FAIL / 0 PASS**, zero timeouts, and
no resource-limit signals. Classification is unchanged from the immediately
preceding dynamic-cross checkpoint, but no former associative-pattern syntax
or refusal diagnostic remains anywhere in the matrix. All eight affected
cores still fail on independent language/provider frontiers. Their final hard
diagnostic counts are Darjeeling OTP 25, CSRNG 28, EDN 129, entropy_src 197,
lc_ctrl 6, top Darjeeling 4, top Earl Grey 6, and Earl Grey OTP 22. This is
compile/elaboration/code-generation evidence, not OpenTitan simulation-pass
coverage. In the same clean ARM Python environment, `regtool.py` regenerated
UART's `uart_reg_pkg.sv` and `uart_reg_top.sv` byte-for-byte identically in
0.15 seconds; their SHA-256 values are
`106f8da3d41f8cfe585a58e91c251e23e76c81d25956cb751f61644023dfa01b`
and `8c40c957fbd7c1155f58d2c7696340b7ea6b82c2b0626ec684463f991538ae27`.

The frozen Caliptra static census completed 105 jobs and 420 compiler
invocations in 58.30 seconds. Icarus passes **53/105** in each assertions,
no-assertions, and synthesis lane versus Slang **54/105**. Classification is
**52 PASS / 1 DEBT / 51 SHARED_SOURCE_OR_CONFIG / 1 SOURCE_ORDER_DEBT /
0 ICARUS_GAP**; the sole Slang advantage remains the known `csrng_raw_wrap`
source-order debt. This is static compile/elaboration/synthesis differential
evidence, not Caliptra DV runtime.

Primary evidence is outside the repository at
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/opentitan-assoc-pattern-postaudit-after239-arm64-20260826T210149-0600/`.
The OpenTitan result JSON, Markdown, and runner-log SHA-256 values are
`f230258ce602775f16ea75bc0450d497bce2df506ec207a765da10fed0be49ab`,
`53d73fd3035cbf81d86e3dc7ac06dbb7bc976cc85dd35ffd7f65cf9bda4eb92e`,
and `0b7d7cb3962f3a7b866a952d21ad54b103e4b893676df0a155d5767db5f480e0`.
The canonical legacy and JSON/VVP logs have SHA-256
`7c78283ae6e82d94a9ea9b54105bf2839479b9bfbfc3ab2aeedc2f2dd5d59d94`
and `299a0b0a1612e1cb01f8c9f936f4091001cdd5c85799b11b64cbb6225337187a`;
the VPI and real-DPI UVM logs have SHA-256
`ee6a19505b08f9d717493a686d8b99a6b2f14996da1e78d2975b048ab07f2588`
and `121c32f9c6375af0d67e50159cae85b5054c1d2488044cf2e3fa553e3a8b5b9a`.
They live under
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/assoc-pattern-postaudit-after239-arm64-20260826/`.
Caliptra evidence is at
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/caliptra-assoc-pattern-postaudit-after239-arm64-20260826T210409-0600/`;
its JSON, Markdown, and console-log SHA-256 values are
`2438c1cd0930bffe915f0537c9213ddcc80761491105d66e85222d3589181d41`,
`706b0e94b68be66fe45ea4d0885fd5f380d643d5471e96078d0bed53112959a7`,
and `bc56323336a888e0ea2b96bd7d569e6890fa77db1c10ebc9bf86dba2aa9496a7`.

## Tooling and invocation gotchas

- Every compiler/runtime invocation used the worktree-local native-ARM64
  install through `evidence/arm64-tooling/resource-runner`; the runner keeps
  the 45-second CPU guard and has no compiler RSS limit.
- Builds were serial (`make -j1`) with Homebrew Bison 3.8.x, Z3, and libffi
  from `/opt/homebrew`. The optional `tgt-fpga` target was installed before
  the JSON/VVP sweep.
- OpenTitan used the ARM Python 3.13 environment and its FuseSoC 2.4.5 entry
  point. Using the ambient Python or resolving the virtual-environment
  `python` symlink bypasses `pyvenv.cfg` and changes imports.
- The Caliptra harness wraps each compiler invocation itself. Wrapping the
  Python harness in `resource-runner` as well lowers the parent's hard CPU
  limit to 45 seconds; its `preexec_fn` then cannot raise a child limit to 190
  seconds and fails before the first compiler. Invoke the ARM Python harness
  directly and retain its inner per-compiler resource-runner wrapper.
- Progress in a quiet UVM simulation cannot be inferred by grepping printed
  timestamps. Wall limits and the explicit simulator time trace are the
  reliable distinction between a long test and a scheduler hang.

## Next independent frontier

The two full-chip cores now first expose a valid SystemVerilog `for`
initializer that mixes an enum declaration and an integer declaration, with a
package-qualified enum variant. Slang accepts the exact forms in both selected
editions. This is one parser mechanism independent of associative literals and
belongs in the next fresh branch after this increment is merged.

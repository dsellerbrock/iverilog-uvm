# IEEE 1800 §§6.8–6.10 and §6.25 probe record

Run on 2026-10-19 on macOS Darwin ARM64 under `~/codex-supervisor/localrun`.
Each compile and simulation used `scripts/run_with_timeout.py 45`. Audit
checkout: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; compiler source:
`b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus SHA-256:
`7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256: `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
Both editions produced the same observed results. The lead classified #765
(§6.9.1 unknown range bound), #766 (§6.25 class-scoped typedef use), and #767
(§6.10 undeclared procedural reference) as new gaps; all three are OPEN with
the `1800-audit` label.

## §6.8 variable declarations and defaults

`p06_08a_vars_defaults.sv` passes 13/13 checks in `-g2017` and `-g2023`.
It tests the `var` forms and shared declarations, default values for 2-state,
4-state, real, enum, string, class, chandle, virtual-interface, and event
variables, static initialization, class `new`, and automatic task locals.
The event default uses a waiter and trigger rather than comparison, so it
avoids the separately reported §6.17 event-comparison gap in #699.
Logs: `attempt-02/`.

## §6.9 vectors

`p06_09a_vectors.sv` passes 10/10 checks in both editions: negative/reversed
range, bit order, signed values, modulo arithmetic, a 65,536-bit vector, and
`scalared`/`vectored` declarations. `n06_09_nonconst_range.sv` rejects as
expected. `n06_09_x_range.sv` (`logic [1'bx:0] v`) compiles silently in both
editions, despite §6.9.1 saying range bounds shall not contain X/Z bits.
Logs: `attempt-01/`.

## §6.10 implicit declarations

`p06_10a_implicit.sv` reports `IMPL w3=1 w4=1 w2=1 bits=1` in both editions,
covering implicit nets at a module port connection, primitive terminal, and
continuous-assignment left side. `default_nettype none` rejects an undeclared
net as expected. `n06_10_gen_scope.sv` compiles with an unresolved-reference
warning and its generated VVP exits successfully without output. In
`attempt-04/`, the paired plain undeclared-identifier control behaves
identically: both print `S`, a blank line, then `E`. The lead classified the
warning-plus-blank-value behavior as a §6.10/§6.21 diagnostic gap in
[#767](https://github.com/dsellerbrock/iverilog-uvm/issues/767). The
generate-scope rule itself remains unassessed because the plain undeclared-
name control fails to diagnose too. Logs: `attempt-01/`, `attempt-03/`, and
`attempt-04/`.

## §6.25 parameterized data types

The standard's example in `p06_25a_param_types.sv` fails at its three
`C#(...)::t_*` type declarations in both editions. A minimal reduction,
`r06_25a_scalar_typedef.sv`, containing only the `C#(bit,3)::t_vector v;`
declaration still fails with a syntax error / `Invalid module instantiation`
in both editions. No VVP artifact was run. `attempt-03/` contains the reduced
logs. Follow-up controls in `attempt-04/` show that the typedef form, the
default specialization `C#()::t_vector`, and a class-property declaration
also fail in both editions. The lead classified this as a new gap and updated
[#766](https://github.com/dsellerbrock/iverilog-uvm/issues/766) to cover
variable, typedef, default-specialization, and class-property declarations;
the controls are recorded in the issue body and comment.

`p06_25b_type_cmp.sv` was intended to check specialized typedef type matching,
but cannot get past the same class-scope typedef declaration. Its result is
not independent evidence about the `type()` operator. The isolated
`r06_25b_type_cmp_min.sv` likewise fails on the declaration, so no §6.23
classification is claimed from it.

## Dedupe

All searches used `gh issue list --state all` (open and closed) and are saved
as `dedupe_*.json`. The terms covered variable defaults and `var` declarations,
implicit nets/declarations and `default_nettype`, X/unknown/range bounds,
`scalared`, `vectored`, parameterized data types, class typedefs and virtual
class typedefs, and implicit generate scope, plus unknown/undeclared/
unresolved identifiers and bindings. No exact issue for the §6.9.1 unknown-
bound gap or §6.10 undeclared procedural reference was found before filing;
#767 records the latter. Parameterized-
type searches returned broad closed #19 and related but distinct #663
(inherited type-parameter members), #666 (parameterized UVM `$cast` with
class localparam), and #672 (nested property path through a parameterized
base). The lead confirmed that closed #19 does not cover the standard's
`C#(...)::t_vector` declaration.

Reduced probes, runners, compiler logs, VVP logs, and dedupe output are stored
in `tests/1800_audit/c06/` and this evidence directory. Localrun wall/RSS:
`attempt-01` 2.36 s / 16,973,824 bytes; `attempt-02` 0.42 s / 16,908,288 bytes;
`attempt-03` 0.93 s / 16,973,824 bytes; `attempt-04` 1.61 s /
16,924,672 bytes.

Standards checked: IEEE 1800-2017 §§6.8–6.10 pp.100–104 and §6.25 pp.137–138;
IEEE 1800-2023 §§6.8–6.10 pp.105–108 and §6.25 pp.144–145.

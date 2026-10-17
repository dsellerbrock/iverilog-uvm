# IEEE 1800 clause 8 audit probes — 2026-10-17

This is a scoped audit of selected features in 1800-2017/2023 §§8.4–8.12 and
8.18, not a claim that the whole clauses are qualified. Paired probe sources
are in [`tests/1800_audit/c08`](../../tests/1800_audit/c08/). Raw results from
each probe batch are preserved beside this record.

The audit lead read both editions and filed ten verified gaps:
[#608](https://github.com/dsellerbrock/iverilog-uvm/issues/608),
[#609](https://github.com/dsellerbrock/iverilog-uvm/issues/609),
[#610](https://github.com/dsellerbrock/iverilog-uvm/issues/610),
[#611](https://github.com/dsellerbrock/iverilog-uvm/issues/611),
[#612](https://github.com/dsellerbrock/iverilog-uvm/issues/612),
[#613](https://github.com/dsellerbrock/iverilog-uvm/issues/613),
[#614](https://github.com/dsellerbrock/iverilog-uvm/issues/614),
[#615](https://github.com/dsellerbrock/iverilog-uvm/issues/615),
[#616](https://github.com/dsellerbrock/iverilog-uvm/issues/616), and
[#617](https://github.com/dsellerbrock/iverilog-uvm/issues/617). `QUALIFIED`
means the named probe subset passed; it does not mean full-clause conformance.

## Build and run provenance

- Host: `MacBook-Air.local`, Darwin 27.0.0, arm64.
- Source: `9b5fad2afb4104caa816b257d5bccc40f01b8c66`, branch
  `m7-1800-audit-c08`.
- Build: `~/codex-supervisor/localrun 1800 bash /tmp/a3-build/build-current-main.sh`;
  `localrun` exit 0, `build_rc=0`, 479.38 s wall, 40,321,024 bytes peak RSS.
  Configure used `--enable-libveriuser`; the build ran serially with Bison 3.8.2.
- Compiler: Icarus 13.0 devel, arm64; SHA-256
  `9e98c3c982456148c2b15e866072448366fec4d5dae4273649d3e0cafcc37ed5`.
- VVP: arm64; SHA-256
  `87a81327f5eddd5d2281190338ea38e128774ff66b08c57b1de724f09a59615b`.
- Libraries/tools: Bison 3.8.2, libffi 3.8.0, Z3 5.1.0. The complete build
  tool output is in [`toolchain.txt`](toolchain.txt).
- Reference copies: IEEE 1800-2017 SHA-256
  `12e3dc7bafafca28af2b89ebc2761fb7a606d68716cf04c2d93c8617c78eebec`;
  IEEE 1800-2023 SHA-256
  `2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`.
- Probe batches used `~/codex-supervisor/localrun 1800`; each compile had a
  60 s alarm and each simulation had a 30 s alarm. Wall time / peak RSS:
  - §8.4–8.8: 3.08 s / 49,299,456 bytes.
  - §8.9–8.12: 2.88 s / 48,250,880 bytes.
  - §8.12 and §13.4 reducers: 1.21 s / 33,783,808 bytes.
  - Minimal §8.12 crash: 0.26 s / 7,077,888 bytes.
- The probe source SHA-256 values are in [`probe-sha256.txt`](probe-sha256.txt);
  localrun output, tool output, and raw results are preserved in the other
  files in this directory.

## Results

All results below are identical under `-g2017` and `-g2023`, except
`type(this)`, which correctly fails under 2017 and passes under 2023. The
initial `vector#(3)::T'(3.45)` assertion failed to compile in both editions;
only that assertion was commented out so the other checks could run. Its
original source line and diagnostics are preserved in
[`first-attempt-results.txt`](first-attempt-results.txt).

The `@e` check in an ordinary function was rejected, while `@e` in `new` was
accepted; `wait` in `new` was rejected. This keeps the reported nonblocking
gap scoped to constructors. The §13.4 ordinary-function check is only a
negative control, not a clause 13 audit.

| Clause | Probe findings | Status | Issue |
| --- | --- | --- | --- |
| 8.4 | Default-null handles, equality/case equality, conditional and compatible/null assignment pass; relational comparison is rejected. Arithmetic and equality between unrelated handles compile. Null dereference runs without a diagnostic, which is permitted for an indeterminate result. | PARTIAL | [#608](https://github.com/dsellerbrock/iverilog-uvm/issues/608), [#612](https://github.com/dsellerbrock/iverilog-uvm/issues/612) |
| 8.5 | Instance property/enum/parameter access passes; instance-qualified type access is rejected; the class-scoped type-parameter cast example fails to compile. | PARTIAL | [#611](https://github.com/dsellerbrock/iverilog-uvm/issues/611) |
| 8.6 | Method calls and automatic method lifetime pass; static method/task lifetime is rejected. | QUALIFIED | — |
| 8.7 | Initialization and argument forms, implicit `new`, local/protected factory access, and rejection of `wait` in `new` pass. Static/virtual constructors and `@e` in `new` compile; module code can call a local constructor. | PARTIAL | [#609](https://github.com/dsellerbrock/iverilog-uvm/issues/609), [#610](https://github.com/dsellerbrock/iverilog-uvm/issues/610), [#613](https://github.com/dsellerbrock/iverilog-uvm/issues/613) |
| 8.8 | Typed constructors, parameterized/named arguments, dynamic type, and incompatible-target rejection pass. | QUALIFIED | — |
| 8.9 | Static property access without an object, through a null handle, and shared updates pass. | QUALIFIED | — |
| 8.10 | Static method/task calls pass; `this` and non-static members in static methods, and `static virtual` methods, compile. | PARTIAL | [#614](https://github.com/dsellerbrock/iverilog-uvm/issues/614), [#615](https://github.com/dsellerbrock/iverilog-uvm/issues/615) |
| 8.11 | `this` disambiguation and handle return pass; `type(this)` passes in 2023 and is rejected in 2017. `this` outside a class fails elaboration with an unresolved-reference warning. | QUALIFIED | — |
| 8.12 | Same-type shallow copy, shared nested handles, no constructor re-run, and mode copying pass. Copying a derived object through a base handle aborts VVP; copied objects produce different next random values. | PARTIAL | [#616](https://github.com/dsellerbrock/iverilog-uvm/issues/616), [#617](https://github.com/dsellerbrock/iverilog-uvm/issues/617) |
| 8.18 | A local constructor works through an in-class factory, but a module-scope call to it compiles. | PARTIAL | [#610](https://github.com/dsellerbrock/iverilog-uvm/issues/610) |

For §8.12, the lead verified the same copy and RNG requirements in both
editions. Issue #101 is not a duplicate: it concerned static initialization
order and states that procedural `b = new source` copies correctly. The
unresolved RNG implementation boundary is reserved for the later §18.14
audit. Clauses 8.13–8.17 and all unlisted features remain unassessed.

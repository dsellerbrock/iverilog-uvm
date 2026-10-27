# IEEE 1800 §§8.20–8.22 virtual methods and polymorphism

This attempt probes the features selected by the audit lead: virtual override
identity (including a non-virtual override of a virtual method and a virtual
override of a non-virtual method), abstract-class construction, pure-method
implementation rules, legal empty method bodies, and dynamic lookup through
superclass handles. The same sources are compiled under `-g2017` and `-g2023`.

Standard references: IEEE 1800-2017 §§8.20–8.22, pp. 184–187; IEEE
1800-2023 §§8.20–8.22, pp. 195–199. Both editions say an identified virtual
method remains virtual in overriding subclasses; §8.21 prohibits direct
construction of an abstract class and requires concrete subclasses to
implement all pure methods. The note in §8.21 explicitly permits a callable
method with an empty statement body and says an `integer` return yields `x`.

Probe sources:

- `tests/1800_audit/c08/p08_20_22.sv` — positive compile and runtime output
- `tests/1800_audit/c08/neg/n08_21_construct_abstract.sv`
- `tests/1800_audit/c08/neg/n08_21_pure_in_concrete.sv`
- `tests/1800_audit/c08/neg/n08_21_missing_implementation.sv`
- `tests/1800_audit/c08/neg/n08_21_pure_with_body.sv`

Expected positive output:

```text
V1 C C
V2 A2 C2
AB1 5
AB2 x
POLY Ether Token GPS
```

The Slurm script compiles and runs each positive edition with a 30-second
process-group timeout, expects each negative source to fail during compilation,
and records compiler diagnostics, exit codes, elapsed time, peak RSS, and
binary/source hashes. Open-and-closed issue dedupe and the lead's
classification will be recorded in `RESULT.md` after the run.

Attempt 01 stopped before compilation because its archive was unpacked at the
wrong directory level. Attempt 02 unpacks `input.tar.gz` under `input/`, which
matches the source path expected by the harness.

## Archive integrity

- `input.tar.gz`: 1529 bytes; SHA-256 `6578ef5a0b0d7a3f6e88f5500a9e6a95fd863ad87354313e5c39e7298940eff3`.

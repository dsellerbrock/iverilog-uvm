# §25.6–§25.7 interface timing and error probes

Host: macOS, both `-g2017` and `-g2023`, each invocation capped at 20 seconds
under `~/codex-supervisor/localrun`. The main probe batch took 0.91 seconds
and peaked at 17,924,096 bytes RSS; the specify reducers took 0.27 seconds and
peaked at 17,612,800 bytes RSS. Specify probes were also rerun with `-gspecify`,
as required by `tests/capability/README.md`.

Toolchain: Icarus build from batch commit
`b9441bafbdb0b6b7413c09e0381845e69481391b`; see the [§25.3–§25.5
results](../ieee1800-audit-c25a-20261019/RESULT.md) for binary SHA-256 values.

## §25.6 specify paths

The standard's `dtype` example using interface signals in a specify path fails
with “Invalid simple path” in both editions, even with `-gspecify`. A reduced
direct module-port path compiles; a `$setup` timing check on interface signals
also compiles and runs; the path-only form with interface terminals fails.
The lead verified legality against §25.6 pp.760–761 and Annex A.7.3 p.1168,
deduped `specify`, `Invalid simple path`, and `module path`, and filed
[#825](https://github.com/dsellerbrock/iverilog-uvm/issues/825). Delay behavior
on a variable output is not claimed.

## §25.7 negative probes

Both editions reject `missing_export` with the specific missing exported-task
implementation diagnostic, `proto_args` with the prototype mismatch
diagnostic, and `import_no_modport_access` because `t2` is hidden by the
modport. These conforming checks exercise §25.7.1–§25.7.2.

`proto_mismatch` and `dup_export` fail at the module-side `task a.Read`
definition, blocked by #823; they are not independent evidence for those rules.
`r_noexport` fails to parse `extern forkjoin` due to #824, so its required
run-time error remains unassessed. Full diagnostics and commands are in
[`attempt-01-no-gspecify-results.json`](attempt-01-no-gspecify-results.json),
[`attempt-02-gspecify-results.json`](attempt-02-gspecify-results.json), and
[`specify-reducers.json`](specify-reducers.json).

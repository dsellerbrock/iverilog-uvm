# §25.3–§25.5 interface and modport probe

Host: macOS. Runner: `~/codex-supervisor/localrun 180`; each compiler or
simulation invocation had a 20-second subprocess timeout. Total runner time was
0.57 seconds; peak RSS was 26,378,240 bytes.

Toolchain:

- `iverilog`: `/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog`
  SHA256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`
- `vvp`: `/tmp/a3-t2-batch-2026-10-19-6-local-r6/source/vvp/vvp`
  SHA256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`

The positive source [`p25_03a_basic.sv`](../../tests/1800_audit/c25/p25_03a_basic.sv)
was compiled with `-g2017` and `-g2023`, top `top`. Both runs failed at line
35: wildcard named port connection `.*` did not find a matching identifier for
interface port `sb_intf`; neither edition ran.

All seven negative sources were compiled under both editions. Results were
identical:

| Probe | `-g2017` | `-g2023` | Observation |
| --- | --- | --- | --- |
| `modport_undeclared` | accepted | accepted | `modport m(input b)` where `b` is not an interface member |
| `modport_enclosing` | accepted | accepted | nested interface modport refers to enclosing interface members |
| `modport_mismatch` | rejected | rejected | incompatible interface/modport selection diagnostic |
| `write_modport_input` | rejected | rejected | write through input modport rejected with §25.5 diagnostic |
| `generic_implicit` | rejected | rejected | generic interface port cannot be left unconnected by `.*` |
| `generic_nonansi` | rejected | rejected | malformed probe; does not establish the intended non-ANSI rule |
| `module_in_interface` | rejected | rejected | module declaration in an interface rejected |

Raw compiler output and exact argument vectors are in [`results.json`](results.json)
and the per-case `.log` files. The audit lead verified the two accepted modport
name probes against §25.5 and filed [#813](https://github.com/dsellerbrock/iverilog-uvm/issues/813)
after open/closed dedupe. The failed wildcard connection is under a separate
reduced probe; it is not yet classified.

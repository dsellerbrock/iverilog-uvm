# §19.5.4 wildcard arrayed transition bin probe

IEEE 1800-2017 and IEEE 1800-2023 §19.5.4 include the arrayed wildcard-transition example `wildcard bins T0_3_array[] = (2'b0x => 2'b1x);`, specifying a separate bin for each of the four matching transition sequences.

## Paired results

The exact arrayed form in [`p19_05_04_wildcard_transition_array.sv`](input/p19_05_04_wildcard_transition_array.sv) compiles under both `-g2017` and `-g2023` with exit 0, but each compiler invocation prints `sorry: wildcard arrayed transition bin 'T0_3_array' is not supported; the bin is dropped.` Simulation exits 0 and reports `observed inst_coverage=100.000000`. That 100% reading is a false positive: the compiler has removed the only bin.

The existing scalar wildcard-transition control [`sv_covergroup_wildcard_transition.v`](../../../ivtest/ivltests/sv_covergroup_wildcard_transition.v) compiles without diagnostics and prints `PASSED` in both editions. This isolates the failure to the arrayed transition form.

Raw edition-specific compiler/runtime output and [`status.tsv`](status.tsv) accompany the inputs. Each compile and run used a 30-second subprocess timeout. The runner is [`run_pair.py`](run_pair.py).

## Toolchain and reproduction

- Host: macOS, Darwin 27.0, arm64.
- Source checkout: `38182f4ba2e7d17c99ab3ea31add1b8d99c51e36`.
- Build: `PATH=/opt/homebrew/opt/bison/bin:$PATH ~/codex-supervisor/localrun 1200 make -j3`; exit 0, 59.16 s, peak RSS 885,506,048 bytes.
- Install: `~/codex-supervisor/localrun 300 make install prefix=/tmp/a3-ieee1800-c19-20261021-install`; exit 0, 1.59 s, peak RSS 40,697,856 bytes.
- Icarus Verilog 13.0-devel `9bd5082b8`; `iverilog` SHA-256 `b92ded447f28bda589f2eac77ea4ec09115687286bb69ada09e3e3a6b14882fc`; `vvp` SHA-256 `22dae2c8cc68f40455ded0f7d66a7a0700f784223b840c4fa3212700c28abc94`.
- Probe command: `~/codex-supervisor/localrun 120 python3 evidence/ieee1800-audit-c19-20261021/attempt-01-wildcard-transition-array/run_pair.py`; exit 0, 0.08 s, peak RSS 18,661,376 bytes.

## Dedupe and disposition

Fresh open/closed searches are recorded in [`DEDUPE.md`](DEDUPE.md). Closed issue [#661](https://github.com/dsellerbrock/iverilog-uvm/issues/661) already says the scalar form was fixed and the arrayed/nonliteral/range forms remain unsupported. This is evidence for that existing gap, not a new issue; the audit lead should update #661 with the exact paired result. A3 did not file or comment.

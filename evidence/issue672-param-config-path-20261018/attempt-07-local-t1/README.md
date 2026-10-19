# #672 T1 validation, local fallback

- Source commit: `96a18cb6a77ea97317e975779b0daac64f551d98`.
- Host: Mac; Slurm was full when this run started.
- Command: `PATH="$PWD/local-install/bin:$PATH" ~/codex-supervisor/localrun 900 bash .github/ivtest_focus_gate.sh regress-vif-parameter-specialization-focus-legacy.list regress-vif-parameter-specialization-focus-vvp.list`
- Result: exit 0; legacy 72/72 and JSON 72/72 passed.
- Toolchain: Icarus 13.0; `iverilog` SHA-256 `4f3fbe94d8cb08d55e37e831a67f85289806acdfebf6bf2f393ac572c9b36d8d`; `vvp` SHA-256 `9cec8fe710d7aa9d1c056658d3a8c2bb0f54a239a96edfaad48ffe871282d208`.
- Wall time: 18.23 s; peak RSS: 22,790,144 bytes.
- Selection: `regress-vif-parameter-specialization-focus-legacy.list` and `regress-vif-parameter-specialization-focus-vvp.list`, chosen from the graph for class specialization and parameterized-member lowering.
- Raw output: `t1.log`.

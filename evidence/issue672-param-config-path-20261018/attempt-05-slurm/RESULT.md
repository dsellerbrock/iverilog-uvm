# #672 T0/T1 — Slurm job 2850

- Source: `bac2fc96a` (`fix: defer generic method seeding until specialization`).
- Host: DAN-DESKTOP, Linux x86_64 / WSL2; 2 CPUs, 4 GiB requested; `COMPLETED`, exit 0, 3m48s. Peak RSS was 1,662,372 KiB during build.
- Build: `autoconf`, `./configure --enable-libveriuser`, `make -j2`, `make install`; all passed. Installed compiler SHA-256: `13aeea7b562d84f10336c58be55ddfaa00d7bfaccd6dc2e8eda9de51105d0f84`; VVP: `23316e83206c733ac861b347042d3ca5a0e8b0ff0c834142c003746ed649d8a1`.

## T0

- Issue regressions: 2/2 legacy, 2/2 JSON passed (`sv_param_config_seed_deferral_{2017,2023}`).
- Smoke: legacy VVP 56/56, VPI 133/133, negative diagnostics 152/152; malformed-runtime checks passed.

## T1 selection and result

Graph query for the `elab_scope.cc` change reached `seed_specialized_method_bodies_()` and `flush_pending_specialized_method_seeds_()`. The affected area is generic class parameter specialization, so T1 used `regress-vif-parameter-specialization-focus-{legacy,vvp}.list`.

- Legacy focus: 72/72 passed.
- JSON focus: 72/72 passed, each test run separately with a 300-second process-group timeout.
- Final `GATE_RESULT=PASS`; full logs, per-test JSON logs, commands, and hashes are retained in `results/` and `logs/`.

## Dual-specialization boundary probe

- Toolchain: Icarus 13.0 devel from `/tmp/a3-m7-672-install`; compiler SHA-256 `d36120c27fb54ed12bfcf7046b04a8fd2da469f8313c646a8241f619c63f9a55`; VVP SHA-256 `9cec8fe710d7aa9d1c056658d3a8c2bb0f54a239a96edfaad48ffe871282d208`.
- Probe: `dual-specialization.sv` instantiates `derived_seq#(cfg_a)` and `derived_seq#(cfg_b)` from the same generic template. Their nested config types have different member layouts (`int pad` and `string pad`) but both expose `value`.
- Command: `/Users/danielellerbrock/codex-supervisor/localrun 120 bash -c 'export PATH=/tmp/a3-m7-672-install/bin:$PATH; iverilog -g2017 -s test -o /tmp/a3-m7-672-dual-specialization.vvp /tmp/a3-m7-672-dual-specialization.sv && vvp -n /tmp/a3-m7-672-dual-specialization.vvp'`.
- Result: exit 0; VVP printed `PASSED`; localrun peak RSS 7,159,808 bytes.
- The initial suggested source was invalid because it declared both `set_a` and `set_b` in one generic class even though each referenced a field absent from the other specialization. This corrected probe tests specialization isolation without those type errors.

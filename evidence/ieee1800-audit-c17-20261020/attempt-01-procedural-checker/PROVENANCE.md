# Provenance

- Probe source SHA-256: `38f97eac5def781b10e3e9145e23de5690dd8ad8ae9eb9ae1531412375795b30`
- Static control source `ivtest/ivltests/sv_checker_basic.v` SHA-256: `5f95fd52f1a25365d578344ac7b1e58e37dd6bc7f26608132a66cc30761a569d`.
- Icarus compiler: `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/iverilog`, SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`
- VVP: same pinned toolchain, SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`
- Slurm job: 3588 on DAN-DESKTOP; start/end timestamps, uptime, and per-case timing/RSS are in `remote-3588/results/`.
- Local reference: Slang 11.0.448+e222e7dc0; both standards were run under `~/codex-supervisor/localrun 60`; logs are `local-slang-2017.log` and `local-slang-2023.log`.

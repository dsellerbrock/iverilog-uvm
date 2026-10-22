# Attempt 06 — local edition flags unavailable

- Host: MacBook-Air.local; localrun, 1 process; exit 1; elapsed 0.22 s; peak RSS 8,208,384 bytes.
- Toolchain: Homebrew Icarus 13.0 stable, `iverilog` SHA-256 `5df81b269e1ff2c965dd00ad5a8071ca17717f416003b3661a18b2dde430e73c`; `vvp` SHA-256 `1a9bdf1f40102f64f015514f5069f99a5dd9f9f38de343ef4c169fb358392`.
- Commands attempted: `iverilog -g2017 -s test ...` and `iverilog -g2023 -s test ...`.
- Result: this stable build only supports language generations through 2012, so both edition switches were rejected before the probe compiled. This is a toolchain setup limitation, not a semantic result. The 2017/2023 probe is run separately with the pinned main toolchain on Slurm in attempt 07.
- Raw version, hashes, compiler diagnostics, exit codes, and localrun resource output are retained in `results/`.

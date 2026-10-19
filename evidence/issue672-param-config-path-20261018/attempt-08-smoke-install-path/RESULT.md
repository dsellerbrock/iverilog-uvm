# T0 smoke setup attempt (environment mismatch)

- Source under test: the #672 implementation plus approved golden (`72b474a17`); only smoke setup is at issue here.
- Host: MacBook Air, macOS 27.0, arm64.
- Command: `~/codex-supervisor/localrun 1200 /bin/bash /tmp/a3-672-smoke.sh`
- Result: exit 1; 165.74 s wall time; peak RSS 116,441,088 bytes.
- Cause: this scratch tree was installed under `/tmp/.../stage/usr/local`, but existing runtime smoke scripts directly invoke `$ROOT/local-install/bin/iverilog` and `iverilog-vpi`. The scripts therefore stopped on missing local-install executables before exercising the associated checks. The raw log is preserved in `failed-smoke.log`.
- Follow-up: rerun T0 from a clean archive with the workflow's standard `--prefix="$PWD/local-install"` install layout.

# #672 approved golden verification

- Source commit: `72b474a179795635c17aa52cb2ae1f10931f830e` (`test(#672): fix specialization diagnostic golden`)
- Host: MacBook Air, macOS 27.0, arm64
- Compiler: Icarus Verilog 13.0 (devel); compiler SHA-256 `41c05b4eeb2870fd3287a12aa00c2f83d24802a84b475fb4af689e082f7b6f5d`; VVP SHA-256 `bb0ac394725438a939051c7830f7f26ea319f228496dc488eaf61bf5c0404d66`
- Command: `~/codex-supervisor/localrun 900 /bin/bash /tmp/a3-672-golden-install-run.sh`; the script staged the built toolchain under `/tmp`, selected the staged compiler with `-B`, and ran `perl ./vvp_reg.pl /tmp/a3-672-golden-check/three-tests.list`. The regression runner applies a 120-second per-test timeout.
- Result: exit 0; 4.49 s wall time; peak RSS 21,200,896 bytes.

```text
sv_param_config_nested_path_2017: Passed.
sv_param_config_nested_path_2023: Passed.
sv_class_type_param_bound_missing_fail: Passed - CE.
Total=3, Passed=3, Failed=0
```

The negative case emits exactly one diagnostic, at `main._ivl_0.poke`, matching the approved golden. The obsolete diagnostic at `main.common.poke` is absent. An earlier local invocation selected the unrelated system `oss-cad-suite` compiler because the build binary lives under `driver/`; that invocation is not counted. The recorded run explicitly selected the branch-built compiler and its staged runtime.

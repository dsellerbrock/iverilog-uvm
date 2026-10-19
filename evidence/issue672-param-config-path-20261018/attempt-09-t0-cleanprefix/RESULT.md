# #672 T0 clean-prefix verification

- Source commit archived and tested: `3781490a2` (contains the approved golden change; later commit is this evidence only).
- Host: MacBook Air, macOS 27.0, arm64.
- Command: `~/codex-supervisor/localrun 1200 /bin/bash /tmp/a3-672-t0-clean.sh`. It archived the source, ran `autoconf`, configured with `--enable-libveriuser --prefix="$PWD/local-install"`, built with `make -j3`, installed, then ran `ci/run-smoke.sh` with `local-install/bin` first in `PATH`.
- Result: exit 0; 409.54 s wall time; peak RSS 1,360,936,960 bytes.
- Smoke: legacy 56/56, VPI 133/133, all 14 reproducers, negative suite 152/152, and all 46 VVP runtime checks passed.
- The issue-specific 2017/2023 reproductions and approved negative-golden test passed 3/3 in `attempt-07-approved-golden/`.
- Compiler and VVP hashes are in `toolchain.sha256`; raw build, install, version and smoke logs are included.
- The first smoke setup attempt is separately documented in `attempt-08-smoke-install-path/`; it used a nonstandard install path, and no simulator checks failed there.

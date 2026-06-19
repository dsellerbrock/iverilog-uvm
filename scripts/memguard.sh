#!/usr/bin/env bash
# memguard.sh MEM_MB WALL_SEC -- cmd [args...]
#
# Run a command under a HARD physical-memory (RSS) cap using a cgroup v2
# transient scope, plus a wall-clock timeout. If the command (and all its
# children, collectively) exceeds MEM_MB of resident memory, the kernel
# OOM-kills *only this scope* -- it cannot take down the machine.
#
# WHY NOT `prlimit --as`: RLIMIT_AS caps *virtual* address space, not RSS.
# OOM is driven by RSS, so an --as cap does NOT prevent physical-RAM
# exhaustion / system OOM. cgroup MemoryMax caps RSS, which is the thing
# that actually kills the box. MemorySwapMax=0 also stops it thrashing swap.
#
# Requires: cgroup v2 (stat -fc %T /sys/fs/cgroup == cgroup2fs) and a systemd
# --user session with the `memory` controller delegated (the default on this
# box). Falls back to prlimit --as with a loud warning if systemd-run is absent.
#
# Examples:
#   scripts/memguard.sh 8000 600 -- make -j4            # build, <=8 GB, <=10 min
#   scripts/memguard.sh 4000 120 -- vvp -n design.vvp   # sim, <=4 GB, <=2 min
set -u
MEM_MB="${1:?usage: memguard.sh MEM_MB WALL_SEC -- cmd...}"
WALL="${2:?usage: memguard.sh MEM_MB WALL_SEC -- cmd...}"
shift 2
[ "${1:-}" = "--" ] && shift

if command -v systemd-run >/dev/null 2>&1 \
   && [ "$(stat -fc %T /sys/fs/cgroup 2>/dev/null)" = "cgroup2fs" ]; then
      exec systemd-run --user --scope --quiet --collect \
            -p MemoryMax="${MEM_MB}M" \
            -p MemorySwapMax=0 \
            -- timeout --signal=KILL "${WALL}s" "$@"
else
      echo "memguard: WARNING: no cgroup v2/systemd-run; falling back to prlimit --as" \
           "(caps virtual size, NOT RSS -- weaker protection)" >&2
      exec prlimit --as=$(( MEM_MB * 1024 * 1024 )) \
            timeout --signal=KILL "${WALL}s" "$@"
fi

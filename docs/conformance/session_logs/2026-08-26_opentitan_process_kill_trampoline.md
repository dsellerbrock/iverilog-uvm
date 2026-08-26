# OpenTitan process-guard self-kill / trampoline unwind (2026-08-26)

## Scope and compatibility target

This is a VVP scheduler/runtime correction for IEEE 1800 process semantics.
OpenTitan and Accellera UVM sources were not changed. IEEE 1800-2017/2023 and
the standard forms accepted by VCS, Questa, and Xcelium are the compatibility
target; Verilator was not used as a semantic or ABI oracle.

## Failure

The unchanged OpenTitan HMAC run reached the UVM process-guard cleanup path and
aborted in `do_join` because the child no longer named the joining thread as
its parent. The exact Accellera shape is a legal self-kill: a process-guard
callback enters nested synchronous functions, and one of those functions calls
`process::kill()` on the current logical process.

`do_disable()` correctly terminates the process root and its synchronous call
frames. It also reaps each frame and clears its parent link. A VVP run pin keeps
the C++ frame object alive until the iterative call dispatcher unwinds, but the
default trampoline path unconditionally passed that already-unlinked frame to
`do_join`. The assertion was therefore a second ownership operation, not an
OpenTitan/UVM source error.

## Fix

The iterative trampoline now checks whether the ending frame is still owned by
the saved caller. A normally returning frame still takes the complete
`do_join` path, including output/ref mirroring and automatic-context
reconciliation. A frame already reaped by `process::kill()` skips that second
join and continues unwinding the next killed frame until the process root is
reached. The caller records every consumed automatic call-site frame in a
LIFO ownership stack: ordinary generated `%free` operations retire records,
while a killed caller releases all outstanding records because source
execution cannot reach their `%free` operations. This includes nested
argument/copy-out calls and a frameless static child above a completed
automatic call. Statements after the self-kill do not resume.

This keeps the modern bounded-C++-stack call engine as the default. The older
recursive call path already recognized the same ownership state; it was useful
for localization, but the implementation was migrated into the trampoline
rather than selecting the legacy engine.

## Permanent evidence

- `sv_process_kill_join_reducer` is a plain IEEE reducer with automatic and
  static nested function frames, an inout array-element argument whose index
  is reevaluated during copy-out, and an independent observer. The parent
  commit aborts with the exact `child->parent == thr` assertion; the fixed
  runtime exits 0 and prints only `PASSED`. It is in the legacy and JSON/VVP
  main manifests and the vthread-resource focus manifests.
- `run_process_kill_call_context.sh` runs that reducer through both the modern
  trampoline and legacy recursive engine and requires the context census to
  report exactly five abandoned caller-owned frames released in each mode.
  It therefore pins cleanup as well as visible non-resumption.
- `uvm_process_guard_join_test` exercises the Accellera process-guard/sequence
  lifecycle with the real UVM DPI umbrella and has an unreachable fatal after
  `seq.start`. The fixed run reports 1 passed, zero failed, and zero skipped.
- The existing call-frame/resource reducers remain in both focus harnesses;
  each harness reports 6/6 after the change.

Representative native ARM64 commands (run from the repository root):

```sh
PATH="$PWD/local-install/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  ../evidence/arm64-tooling/resource-runner \
  bash .github/regression/run_uvm_subset.sh uvm_process_guard_join_test

cd ivtest
PATH="$PWD/../local-install/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  ../../evidence/arm64-tooling/resource-runner \
  perl vvp_reg.pl regress-vthread-resource-focus-legacy.list
PATH="$PWD/../local-install/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  ../../evidence/arm64-tooling/resource-runner \
  /opt/homebrew/opt/python@3.13/bin/python3.13 \
  vvp_reg.py regress-vthread-resource-focus-vvp.list
```

## Exact-tree validation

The final native ARM64 tree passes the 23/23 scheduler focus, the 37/37 real
DPI focus, the complete 353/353 real-DPI UVM harness, the 4,088-test legacy
gate with zero unexpected failures, JSON/VVP 973/973, VPI 103/103, negative
diagnostics 131/131, every runtime invariant, and `make -j1 check`.
`run_dpi_prefixless_vec4_compat.sh` additionally executes a valid old-format
`%dpi/call/vec4` image whose argument signature has no new return-ABI prefix.

Pinned Slang 11 accepts the process-kill reducer in IEEE 1800-2017 mode. Across
the broader lifetime/process source set it accepts 10/11. The one rejection is
fixed-array-element `force`/`release`; IEEE 1800-2017 and 2023 §§6.4 and 10.6.2
permit a reference to the selected singular integral variable, so this is a
recorded oracle disagreement rather than an Icarus restriction.

The unchanged precompiled HMAC image was also replayed through the campaign
resource runner with its ARM64 DPI bundle and both required plusargs. It
advanced to 210,327,516 ps with no scheduler assertion, other assertion,
UVM error or fatal, loader failure, or crash before the 45-second CPU guard.
The externally interrupted thread reports one residual vec4 stack item during
guard teardown. That bounded slice does not reach the former
1,339,336,540 ps assertion point, so it is supporting frontier evidence, not
the red/green proof; the two exact reducers above provide that proof.

The focused unchanged Caliptra `axi_pkg.sv` and `axi_if.sv` sources at
`bd31614182fb56e55578f48086a10ded650434fd` also compile with zero diagnostics,
and their VVP image loads and exits normally. There is no testbench or AXI
transaction in that witness, so it proves package/interface elaboration and
image loading only, not a full Caliptra application run.

## Invocation gotcha

Harnesses that enter `ivtest` must receive an absolute worktree install path.
Starting `.github/ivtest_gate.sh` with the relative entry
`PATH="local-install/bin:$PATH"` invalidates that entry after the `cd` and can
silently select Homebrew Icarus. Use `PATH="$PWD/local-install/bin:$PATH"` at
the repository root (or `$PWD/../local-install/bin` from inside `ivtest`).

# Repository Guidelines

## Project Structure & Module Organization
This repository is the iverilog source tree: the compiler, elaborator, code generators, and `vvp` runtime. Common areas are `tgt-vvp/` for VVP code generation, `vvp/` for the simulator runtime, and `ivtest/` for regression drivers and gold files. In the development *workspace* (a wrapper directory that is not itself a git repo), this repo sits alongside `accellera-official.uvm-core/` and `uvm_testbench/`, which are used for SystemVerilog/UVM compatibility validation rather than core product sources. Paths below are relative to this repository root.

## Build, Test, and Development Commands
`/home/daniel/uvm_iverilog` is a workspace wrapper, not a git root. The main repository and build tree are under `iverilog/`. Sibling directories such as `accellera-official.uvm-core/` and `uvm_testbench/` are the library/application-style validation assets we build and test against from this wrapper.

Run all build commands from `iverilog/` unless noted.

> **MEMORY SAFETY (mandatory).** This host's interactive agent/harness runs with a high OOM
> priority (`oom_score_adj` ~200), so any session-wide memory spike gets the *harness* killed
> first — not the build/sim that caused it. Therefore **wrap every heavy command in the cgroup
> memory guard** `scripts/memguard.sh MEM_MB WALL_SEC -- <cmd>`, which runs it in its own cgroup v2
> scope with a hard RSS cap (`MemoryMax`) so an OOM is contained inside that scope. Examples:
> `scripts/memguard.sh 6000 600 -- make -j2` and `scripts/memguard.sh 4000 120 -- vvp design.vvp`.
> Use **`-j2`** (a single `vvp/vthread.cc` TU alone peaks ~656 MB RSS); never bare `make -j$(nproc)`
> (= `-j24` here). Do NOT use `prlimit --as` as a guard — it caps virtual size, not RSS, and does
> not prevent OOM. `install/` is persistent disk, so after a reboot the last-installed binaries are
> still valid — only rebuild when source changed. Clean `/tmp/*.vvp` after runs (`/tmp` is tmpfs = RAM).

- `sh autoconf.sh && ./configure --enable-libveriuser`: generate configure files and prepare a local build.
- `scripts/memguard.sh 6000 600 -- make -j2`: build the compiler, targets, and `vvp` runtime (memory-guarded; preferred). Bare `make -j$(nproc)` is unsafe here — see MEMORY SAFETY above.
- `make check`: run the built-in pre-install checks.
- `make install`: install into the configured prefix; this workspace commonly uses `iverilog/install/` for local testing.
- `cd ivtest && ./vvp_reg.pl --strict`: run the main simulation regression suite.
- `./.github/test.sh`: run the CI-style smoke test set.
- For local compiler validation against the freshly installed targets, prefer `./install/bin/iverilog -B ./install/lib/ivl ...` so the driver uses the just-built target modules instead of any stale default search path.

For incremental work, prefer ordered rebuilds of the touched areas before a full `make install`, for example `make -C vvp -j4`, `make -C tgt-vvp -j4`, then `make -j4 install`. Avoid launching overlapping writes to the same build outputs from multiple shells; generated headers, opcode tables, object files, and installed binaries can race and leave a misleading mixed build.

## Coding Style & Naming Conventions
Match the surrounding file exactly; this codebase does not use a single autoformatter. C and C++ sources generally use K&R braces, aligned continuation indents, and descriptive helper names such as `draw_*`, `emit_*`, `Net*`, and `P*`. Keep edits narrow, prefer ASCII, and avoid unrelated reformatting. Use `cppcheck` targets when touching low-level runtime or driver code, for example `make cppcheck` or `make -C vvp cppcheck`.
When adding VVP instructions, update `iverilog/vvp/codes.h` and the operand decoding in `iverilog/vvp/compile.cc` together. In `iverilog/vvp/compile.cc`, keep the opcode table strictly sorted by mnemonic because opcode lookup uses a binary search.

## Testing Guidelines
Every bug fix or feature should add or update a regression. When debugging a runtime, elaboration, or UVM issue, first reduce it to the smallest focused reproducer you can, keep that test under `iverilog/ivtest/ivltests/`, and add it to the appropriate regression list so the failure stays covered after the fix lands. Keep focused tests near the existing `ivtest` suites and use existing list/gold patterns. For runtime or elaboration work, run the smallest targeted reproducer first, then `./vvp_reg.pl --strict`, and finally any relevant UVM smoke test from the workspace. Before treating a new failure as a fresh frontier, check [`FALLBACKS.md`](FALLBACKS.md) and rule out the active fallback/workaround paths first.

## Commit & Pull Request Guidelines
Recent history favors short, imperative commit subjects such as `Add test for br_gh1248` or `Fix manual PDF generation`. Keep commits scoped to one logical change. For PRs, create a branch named `my-github-id/feature-name`, target `master` or the relevant release branch, summarize behavioral impact, and list the exact tests run. PRs are expected to pass CI and regression tests before merge.

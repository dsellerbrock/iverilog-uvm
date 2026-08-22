# Repository agent guide

## Mission

- Implement SystemVerilog behavior against IEEE 1800-2017 and run unmodified UVM workloads.
- Use Slang as a differential semantic reference where applicable. Record intentional extensions or divergences instead of silently treating them as IEEE behavior.
- Never turn unsupported behavior into silent success. Emit a focused `error`, `sorry`, or warning and add a regression that pins the boundary.
- Preserve source evaluation order, scope and type provenance, scheduler-region semantics, DPI/VPI ABI behavior, and exact diagnostic counts.

## Worktree and Git lifecycle

- Work only in the intended repository/worktree. Inspect `pwd`, `git status --short --branch`, and the current upstream before editing.
- Preserve unrelated user changes and dirty worktrees. Do not reset, clean, or overwrite them.
- Once a PR is merged, stop using its branch. Fetch `origin/main`, verify the merge is present, and start the next change on a fresh branch/worktree based on the updated `origin/main`.
- Stage explicit paths with `git add -- <paths>`; do not use `git add -A` in a mixed or generated worktree.
- Do not commit build products, dependency files, local installation trees, logs, cores, `a.out`, generated parser files, or `.dSYM` content.

## Build

- For a checkout from Git, run `sh autoconf.sh`, configure a repository-local install prefix, then build and install.
- A typical macOS configuration is:

  ```sh
  PATH="/usr/local/opt/bison/bin:$PATH" \
  CPPFLAGS="-I/usr/local/opt/libffi/include" \
  LDFLAGS="-L/usr/local/opt/libffi/lib" \
  ./configure --prefix="$PWD/local-install" --enable-libveriuser
  make -j4
  make install
  ```

- Adapt Homebrew paths with `brew --prefix` where necessary. This fork requires Z3 and libffi.
- On Apple Silicon, verify `uname -m`, the compiler, Python, native extension
  modules, and installed Icarus binaries all report `arm64`. Never reuse an
  install tree or virtual environment created under Rosetta. Start with
  `make distclean`, configure against `/opt/homebrew`, and use
  `CFLAGS="-g0 -O2" CXXFLAGS="-g0 -O2"`. Run the bounded build serially:
  two simultaneous Clang C++ jobs can exceed the campaign's 1 GiB aggregate
  RSS ceiling even when each compilation is healthy.
- Before a full JSON ivtest run, install the optional FPGA target with `make -C tgt-fpga install`; the root `make install` does not install `fpga.conf`/`fpga.tgt`, and two FPGA diagnostic tests otherwise fail before reaching their expected errors.
- After source edits, build the directly affected objects first. Before handing off, use `make -q` for those objects and run `git diff --check`.
- If parser grammar changes, report Bison conflict counts and whether the conflict-state signature changed.

## Tool pinning

- Test the compiler and runtime built from the current worktree. Do not trust ambient `/usr/local/bin/iverilog` or an old installed `vvp`.
- OpenTitan pins FuseSoC 2.4.5. Invoke `scripts/opentitan_matrix.py` with the
  Python from the same tool environment and pass it through
  `--fusesoc-python`; do not replace a virtual-environment `python` symlink
  with its real path, because that bypasses `pyvenv.cfg` and changes imports.
- On Apple Silicon, create that environment with native
  `/opt/homebrew/opt/python@3.13/bin/python3.13`. The ambient Homebrew
  `python3` may be 3.14, which is outside OpenTitan's supported range. Recreate
  the environment from OpenTitan's hashed requirements; do not relink an old
  `/usr/local` environment because its compiled wheels remain x86_64.
- Run OpenTitan generators through that same Python, for example
  `"$TOOL_PY" util/regtool.py ...`, and write generated comparison output
  outside the read-only OpenTitan checkout.
- From `ivtest`, prefer:

  ```sh
  PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl <list>
  PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py <list>
  ```

- When a generated artifact's shebang may select a stale runtime, invoke the current repository `vvp/vvp` explicitly.
- Record the exact compiler/runtime path in failure reports when tool provenance could affect the result.
- Run legacy and JSON ivtest focus harnesses serially unless each has an
  isolated work directory; both otherwise use `ivtest/log` and can delete one
  another's evidence.

## Test pyramid

Run the narrowest meaningful gate first, then widen it:

1. Build affected objects; run focused positive and negative reproducers.
2. Check exact diagnostics/output and Slang polarity where relevant.
3. Run both focused ivtest harnesses: legacy gold and JSON/split-stream gold.
4. Run the integrated ivtest/VPI/negative suites appropriate to the change.
5. Run the full external `sv-tests` suite only after the known feature cluster is clean; do not spend a broad run on every intermediate patch.
6. After the SystemVerilog frontier is clean, run whole OpenTitan synthesis/SVA/UVM workloads, then Caliptra.

- Distinguish unexpected failures from recorded `NI` and expected failures in every summary.
- Preserve a reduced permanent regression for every bug fix. A red proof against the previous compiler is valuable when practical.
- Do not call a partial feature complete while known semantic or transactional gaps remain.
- For the real-DPI UVM regression, initialize `uvm-core`, run `make installuvm`, then use `PATH="$PWD/local-install/bin:$PATH" bash .github/uvm_test.sh`.

## Regression artifacts

- Positive tests should prove behavior, not merely compilation. Negative tests should pin focused diagnostics and counts.
- For ivtest additions, normally provide the source, legacy gold, JSON config, split-stream gold, focused-list entry, and main-manifest entry.
- Verify every new basename occurs exactly once in each intended manifest and nowhere unintended.
- Keep focused lists small enough to rerun during development. Document deliberately unregistered research or known-gap probes.
- Exact-output gold files may contain intentional whitespace; source files may not.

## Implementation and review rules

- Search with `rg`/`rg --files` before changing code and follow the existing ownership boundaries between parser, elaboration, target lowering, runtime, and VPI/DPI.
- Changes to VVP instructions generally require synchronized updates to opcode declarations, compiler parsing, target emission, runtime execution, and malformed-bytecode validation where applicable.
- For randomization changes, preserve deterministic RNG ownership and consumption, atomic value/history rollback on failure, static alias identity, and per-leaf state where the LRM defines independent variables.
- For SVA/deferred work, preserve the specified sampling and scheduler region; never escape into Active/Reactive from a Postponed-only action.
- Treat crashes, null dereferences, unchecked VPI/DPI casts, malformed bytecode handling, use-after-free, and transient callback leaks as security-relevant findings and call them out explicitly.
- Review for silent fallback, stale-runtime execution, lost diagnostic counts, host-specific paths, generated artifacts, and claims broader than the tests prove.

## Commit and pull request

- Commit at a coherent, tested boundary. Push the feature branch and open a draft PR when the change is ready for review.
- Follow `.github/pull_request_template.md` completely. Include the IEEE clause, reduced bug, root cause, implementation scope, exact tests/commands/results, compatibility impact, and known limitations.
- Update the conformance matrix or other durable documentation for semantic support changes.
- Do not merge until required checks are green. If CI exposes a latent regression, fix it in a focused follow-up and repeat the fresh-main branch lifecycle after that PR merges.

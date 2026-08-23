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
- The Apple Silicon configuration for this campaign is:

  ```sh
  PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/bin:$PATH" \
  CPPFLAGS="-I/opt/homebrew/opt/libffi/include -I/opt/homebrew/opt/z3/include" \
  LDFLAGS="-L/opt/homebrew/opt/libffi/lib -L/opt/homebrew/opt/z3/lib" \
  CFLAGS="-g0 -O2" CXXFLAGS="-g0 -O2" \
  ./configure --prefix="$PWD/local-install" --enable-libveriuser
  make -j1 YACC=/opt/homebrew/opt/bison/bin/bison LEX=/usr/bin/flex
  make install
  ```

- Do not substitute `/usr/local` paths on Apple Silicon. This fork requires
  the `/opt/homebrew` Z3 and libffi libraries. Apple `/usr/bin/bison` is
  native-capable but version 2.3 and is too old; pin Homebrew Bison 3.8.x.
- This campaign runs natively on Apple Silicon; assume the compiler, Python,
  extension modules, and installed Icarus binaries are ARM64 instead of
  repeatedly spending runs rechecking the host architecture. Never reuse a
  known Rosetta-era install tree or virtual environment. Start a replacement
  build with `make distclean`, configure against `/opt/homebrew`, and use
  `CFLAGS="-g0 -O2" CXXFLAGS="-g0 -O2"`. Keep builds serial.
- Before a full JSON ivtest run, install the optional FPGA target with `make -C tgt-fpga install`; the root `make install` does not install `fpga.conf`/`fpga.tgt`, and two FPGA diagnostic tests otherwise fail before reaching their expected errors.
- After source edits, build the directly affected objects first. Before handing off, use `make -q` for those objects and run `git diff --check`.
- If parser grammar changes, report Bison conflict counts and whether the conflict-state signature changed.

## Tool pinning

- Test the compiler and runtime built from the current worktree. Do not trust ambient `/usr/local/bin/iverilog` or an old installed `vvp`.
- On this workspace, use only this worktree's `local-install` prefix. Sibling
  Icarus install trees are Rosetta-era x86_64 artifacts, and Homebrew's arm64
  Icarus is the wrong semantic revision even though its architecture matches.
- Run compiler/simulator commands through
  `../evidence/arm64-tooling/resource-runner`, or through the peak-reporting
  native wrapper under `../evidence/caliptra-leading-underscore-20260816/`.
  Do not execute the old sv-tests runner by its broken x86-era shebang. Retain
  the 45-second CPU guard, but do not impose a compiler RSS ceiling for the
  current campaign: set `RESOURCE_RUNNER_RSS_LIMIT_BYTES=9223372036854775807`
  when using a legacy wrapper that otherwise supplies a default cap. Observe
  memory and investigate genuinely abnormal growth instead of terminating a
  legitimate large elaboration at a fixed byte threshold.
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
- Keep the OpenTitan virtual environment first on `PATH`: FuseSoC generators
  and regtool scripts use `python3` shebangs. Invoke the logical venv Python
  path (do not resolve its symlink), and pass that identical path through
  `--fusesoc-python`.
- Never reuse an OpenTitan FuseSoC build root created on another host
  architecture. Generated `.vvp` launchers embed the `vvp` path selected at
  build time, and per-core simulation directories may also retain native
  DPI/VPI objects. Regenerate the complete matrix in a fresh ARM64 build root
  with the active worktree's `iverilog`, then architecture-audit every native
  artifact before running it.
- Load DPI bundles with the active `vvp` runtime's `-d <bundle>` option.
  `-M/-m` is for VPI modules and is wrong for Caliptra's `jtagdpi.vpi` and
  OpenTitan's AES DPI bundle. Architecture-check every additional per-core DPI
  dependency; one native AES bundle does not certify the entire runtime matrix.
- Keep Caliptra's `+timescale+1ns/1ps` command file and filtered full-TB
  manifest at durable paths. Do not reuse vanished `/tmp` timescale or AXI
  checker paths from historical evidence.
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

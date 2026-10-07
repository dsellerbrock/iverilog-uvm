# IEEE 1800-2023 class `:final`

The source frontend now accepts a final class extending an ordinary parent,
rejects direct and parameterized subclassing of a final base, and rejects
`:final` under strict 2017.

## Validation

- Source frontend build: `PATH=/opt/homebrew/opt/bison/bin:$PATH CPATH=/opt/homebrew/opt/libffi/include:/opt/homebrew/opt/z3/include LIBRARY_PATH=/opt/homebrew/opt/libffi/lib:/opt/homebrew/opt/z3/lib make -j2 ivl` — passed on macOS.
- Grammar accounting: Bison 3.8.2 with the Makefile parser-generation flags reports 574 shift/reduce and 1,122 reduce/reduce conflicts across 210 conflict states for both `origin/main` at `fc9d8b86` and this grammar. The per-state conflict-count distribution is identical; the `:final` production added no conflicts.
- VVP target plugin: `make -C tgt-vvp -j2 CC=clang 'LDFLAGS=-undefined dynamic_lookup' vvp.tgt` — passed on macOS.
- Focused paired gate: `PATH=/tmp/class-final-bin:/opt/homebrew/bin:$PATH bash .github/ivtest_focus_gate.sh regress-class-final-focus-legacy.list regress-class-final-focus-vvp.list` — legacy 4/4 and JSON/VVP 4/4 passed. The temporary `iverilog` wrapper selects the source-built macOS frontend; the `vvp` wrapper uses the existing 4 GiB-capped Linux runtime. The positive case printed `PASSED`.
- The local `vvp` wrapper translated the temporary frontend's VPI module paths to `/usr/local/lib/ivl` in the existing container. No compiler or runtime image was rebuilt in Linux for this change.
- `python3 -m json.tool` on the four JSON configs and `git diff --check` — passed.

No Linux source build or broad suite was run for this small parser/elaboration change. Cross-platform PR CI remains pending.

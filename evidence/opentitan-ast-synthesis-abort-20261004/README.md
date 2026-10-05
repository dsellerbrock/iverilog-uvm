# OpenTitan AST synthesis abort reproducer

The component-sized standalone reduction of `rglts_pdm_3p3v.sv` from census15 is the permanent synthesis regression at [`ivtest/ivltests/synth_ast_rglts_pdm_nexus_cache.v`](../../ivtest/ivltests/synth_ast_rglts_pdm_nexus_cache.v). It is reliable but has not been reduced to a tiny testcase. Its `unique case (rgls_sm)` is at line 176 (line 171 in the original source). Removing the FSM alone or the FSM plus VCC POK stretch blocks did not reproduce the abort.

The standalone file omits the `prim_assert.sv` include and supplies the two `ast_pkg` timing parameters locally. The assertions using that include are excluded by `-DSYNTHESIS`.

## Reproduce

```sh
/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926/local-install/bin/iverilog \
  -g2012 -srglts_pdm_3p3v -S -DSYNTHESIS \
  -o /tmp/ast-rglts.vvp \
  /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926/ivtest/ivltests/synth_ast_rglts_pdm_nexus_cache.v
```

On 2026-10-04, the unmodified local compiler aborted 20/20 runs with exit 134 (`SIGABRT`). The census crash report points to invalid free detection in malloc, through `Nexus::connect(Link&)` → `NetCase::synth_async` → `NetProc::synth_sync`.

## Pointer-cache control

A disposable compiler build removed only the `default_out_nex` / `default_ena_nex` Nexus-pointer cache and passed the live `default_out.pin(mdx)` / `default_ena.pin(mdx)` Links to `connect`. It retained the existing `default_full_case` calculation and `if (!default_full_case[mdx])` status check. This pointer-only variant passed 20/20 runs; the unchanged compiler aborted 20/20 on the same source and flags.

That disposable control passed 20/20 and strongly implicates reusing cached `Nexus*` values in this shape.

## Generation-guarded candidate

The worktree candidate keeps the cache but records `Nexus::identity_generation()` with each cached pointer and refreshes it from the stable `Link` after any Nexus deletion. Its source files match the candidate build under `/private/tmp/pi/ast-abort-pointer-only-variant-20261004-source` by SHA-256. The candidate backend at `/private/tmp/pi/ast-cache-generation-fix-20261004/lib/ivl/ivl` (SHA-256 `a55408edce6e223df99061590c9055cfc055f503a628810248c723f5390d4b00`) passed this regression 20/20; `synth_sparse_case`, `synth_case_nested_default_cache`, and `synth_case_wide_select_fallback` also passed 3/3. The regression source SHA-256 is `8519f1613cf103727972955eb76fb16a0c66ae662398570327b61dd3e75cf528`. Source hashes: `netlist.h` `f706bcd0139b70ccf9a49defd697f3d191aeba234144e0054b4ea7caca792f76`; `net_link.cc` `e1e2d77f7ab744b50d361a246d23ebf5e391fa21e2bd6ee6c1b4ee78a5b58b05`; `synth2.cc` `e49c85207f2c2464603b739d6eb74f04b3563a01c22a8354aadacf097961abc4`. This is focused evidence only: the current full OpenTitan runtime run uses the installed pre-candidate compiler, and the candidate still needs the refreshed RTL/SVA/UVM census.

# `ivlpp` square-bracket macro-actual assessment

## Standards requirement

IEEE Std 1800-2017 §22.5.1 (`define), p. 678, states: “Actual arguments and defaults shall not contain comma or right parenthesis characters outside matched pairs of left and right parentheses (), square brackets [], braces {}, double quotes "", or an escaped identifier.”

IEEE Std 1800-2023 §22.5.1 (`define), p. 709, repeats that rule and additionally names triple quotes. Both editions explicitly include matched `[]`; the comma inside matched square brackets must not split macro actuals. These are local IEEE PDFs at `/Users/danielellerbrock/projects/iverilog_uvm/reference-standards/local/IEEE_Std_1800-2017.pdf` and `.../IEEE_Std_1800-2023.pdf`.

## Current compiler evidence

Compiler: Icarus Verilog 13.0 (devel), local installed `iverilog` SHA-256 `1590b064aee694d390f8e18b1ca3469a5a47405397db9b8e385b6c5b41f1a5a2`; installed `ivlpp` SHA-256 `35d983cb76b8df6ad118cfa7add3bb84d384eae38667ea0ffd9d6f54c42ccd21`; installed `ivl` SHA-256 `6460085bb07160bc45806eab0af310c0437c936f5a4214bec8ce07fcbb4f3ef6`. Current source `ivlpp/lexor.lex` SHA-256 `f2b3559129de73e295ab761d3b10feeae038fa66eefd875ab830471e0081a3b1`.

`bracket_actuals.sv` runs through `iverilog -E -g2017` and `-g2023`. Both return 1 with `error: too many arguments for \`SECOND` at line 4, the call `SECOND(array_handle[index_a,index_b], 73)`. Preprocessed output has `VALUE = ;` while later controls expand correctly. This is an isolated preprocessor result; the bracket payload is intentionally only a delimiter reducer, and no downstream SV-expression/runtime claim is made for it.

Positive control `controls.sv`: compile `iverilog -g2017 -o evidence/macro-bracket-assessment-20260923/controls.vvp evidence/macro-bracket-assessment-20260923/controls.sv` exits 0; run via local `vvp` exits 0 and prints `controls PASS`. It covers a comma nested in parentheses, a comma in a brace assignment pattern, and a one-argument scalar. It passes `-g2023 -E` as well.

The follow-up compile/runtime reducer `unused_range_macro.sv` uses a balanced `[1,2]` as the discarded first argument of `SECOND(a,b)`, leaving the second argument as a valid string expression. It fails to preprocess with the same “too many arguments” diagnostic in both editions; the matched parenthesis control `unused_range_control.sv` compiles and runs with `PASS control macro` in both. Exact outputs are in `unused_range_result.json`. A proposed `inside {[1,2]}` runtime oracle was rejected because this compiler also fails to parse that direct control; `inside_range_result.json` preserves that separate failed probe and is not evidence for the macro bug.

Malformed bracket reducer `malformed_bracket.sv` uses `SECOND(array_handle[index_a,index_b, 73)` and preprocessor exits 1 (“too many arguments”). This confirms the scanner does not balance brackets; it is not being presented as a standards-valid source case.

The separate `mismatched_group_macro.sv` negative exposes an existing false acceptance in both editions: `SECOND((1,2}, "PASS")` compiles and runs, printing `ACCEPTED mismatched group`. The comma in `(1,2}` is not inside a *matched* delimiter pair, so §22.5.1 cannot treat it as protected. The existing single depth counter lets `}` close `(`. The eventual correction needs type-aware nesting rather than adding `[]` to the counter alone; see `mismatched_group_result.json`.

## Root cause and ownership

In current `ivlpp/lexor.lex`, `MA_ADD` increments `ma_parenthesis_level` for `[({]` (currently only `(` and `{`) and decrements for `[)}]` (currently only `)` and `}`). Commas call `macro_finish_arg()` when this integer is zero. `[` and `]` fall through the default rule and never affect depth, so the first comma inside a bracket pair is incorrectly treated as a macro-argument separator. The smallest complete scanner correction belongs in `ivlpp/lexor.lex`, with balanced `[`/`]` nesting and mixed-delimiter boundary tests; avoid accidentally letting a mismatched delimiter balance an unrelated opener.

This file is outside the Claude-owned elaboration/vvp files and PR329/330 (`elab_expr.cc`/`pform.cc`) scopes. However, `ivlpp/lexor.lex` is already the coordinator-integrated macro-cast fix surface; this assessment does not establish independent ownership for edits. Coordinator should own any follow-on patch or explicitly assign the same file before implementation. No source was changed here.

## Reproduction commands

From the campaign worktree root:

```sh
local-install/bin/iverilog -E -g2017 -o evidence/macro-bracket-assessment-20260923/bracket_actuals.2017.pp evidence/macro-bracket-assessment-20260923/bracket_actuals.sv
local-install/bin/iverilog -E -g2023 -o evidence/macro-bracket-assessment-20260923/bracket_actuals.2023.pp evidence/macro-bracket-assessment-20260923/bracket_actuals.sv
local-install/bin/iverilog -g2017 -o evidence/macro-bracket-assessment-20260923/controls.vvp evidence/macro-bracket-assessment-20260923/controls.sv
local-install/bin/vvp evidence/macro-bracket-assessment-20260923/controls.vvp
local-install/bin/iverilog -E -g2017 -o evidence/macro-bracket-assessment-20260923/malformed_bracket.2017.pp evidence/macro-bracket-assessment-20260923/malformed_bracket.sv
```

Captured stdout/stderr/status and preprocessed output are colocated in this directory.

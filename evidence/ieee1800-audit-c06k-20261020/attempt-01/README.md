# IEEE 1800-2017/2023 §6.10 generate-scope implicit-net probe

## Question and standard basis

IEEE 1800-2017 §6.10 p.103 and IEEE 1800-2023 §6.10 p.108 say an implicit
net introduced in a generate block belongs only to that generated scope. A
same-named continuous-assignment left side in a sibling generated scope may
therefore introduce a distinct implicit net.

`tests/1800_audit/c06/p06_10b_generate_implicit_scope.sv` assigns `1'b1` and
`1'b0` to the same undeclared identifier in sibling generate blocks, then
checks their hierarchical references separately. The pass condition is that
both editions compile and print `PASS: distinct generate-scope implicit nets`.

## Result

Both `-g2017` and `-g2023` compiled and ran successfully with that output.
The probe confirms distinct implicit nets in sibling generate scopes; no new
gap or issue was identified. This closes the unassessed point in the §6.10
summary. It does not retest the separate undeclared procedural-reference gap
tracked by #767.

Command: `~/codex-supervisor/localrun 120 sh evidence/ieee1800-audit-c06k-20261020/attempt-01/run.sh`

Compiler source commit: `b9441bafbdb0b6b7413c09e0381845e69481391b`.
Icarus SHA-256: `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`.
VVP SHA-256: `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
Host: macOS Darwin ARM64. Elapsed: 0.24 s. Peak RSS: 16,924,672 bytes.

Compile and run logs for both editions are beside this file. The audit lead
classification is pending because `ask-techlead --lead 1800-audit` reported
the daily cap reached (160).

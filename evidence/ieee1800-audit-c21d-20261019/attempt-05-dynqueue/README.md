# §21.4.1 dynamic-array and queue probe

- Source: [p21_04b_dynqueue.sv](../../../../tests/1800_audit/c21/p21_04b_dynqueue.sv), copied unchanged from the audit lead.
- Host: MacBook Air; each edition wrapped with `~/codex-supervisor/localrun 180`.
- Compiler/runtime: pinned batch build commit `b9441bafbdb0b6b7413c09e0381845e69481391b`; compiler SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; vvp SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
- Command, per-edition logs, and generated memory files are recorded here. Lead expects 3/3 in both editions; extra-word warnings are permitted.

Observed: both editions exit 1 at run time with four errors: read into the dynamic array, read into the queue, write the dynamic array, and read it back all report that the second argument must be a memory. No RESULT line is printed. This extends the #803 behavior; the raw logs are p21f-2017.log and p21f-2023.log.

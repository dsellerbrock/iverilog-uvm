# IEEE 1800 §§21.3.4–21.4 probe

- Probe: [p21_03c_fileread.sv](../../../tests/1800_audit/c21/p21_03c_fileread.sv), copied unchanged from the active audit lead's prescribed source.
- Host: MacBook Air, wrapped per edition with `~/codex-supervisor/localrun 180`.
- Compiler/runtime: batch commit `b9441bafbdb0b6b7413c09e0381845e69481391b`; compiler SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; vvp SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
- Each edition is compiled and simulated from this evidence directory so its generated input files stay beside the logs. See `command.txt` and per-edition logs.
- Expected from lead: `RESULT pass=17 fail=0` in both editions.

Results: both editions compiled and simulated successfully with `RESULT pass=17 fail=0`.

- 2017: exit 0, 0.08 s, peak RSS 6,799,360 bytes.
- 2023: exit 0, 0.04 s, peak RSS 6,750,208 bytes.
- Dedupe for #802 checked all issue states with `%p enum` and `%p enumeration`; existing #801 is a distinct associative-array-of-struct gap.

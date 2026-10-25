# IEEE 1800-2017/2023 §11.4.14.4 greedy streaming-unpack probe

IEEE 1800-2017/2023 §11.4.14.4 says an unbounded dynamic item greedily takes
the remaining stream after later fixed-size items are reserved, and later
dynamic items remain empty. The probe also checks a single dynamic item
consumes the full stream.

`tests/1800_audit/c11/p11_14_4_greedy_unbounded.sv` unpacks `32'h11223344`
into two dynamic byte arrays and a fixed byte. It expects the first array to
contain `11 22 33`, the second to be empty, and the fixed byte to contain
`44`. It then unpacks `32'h55667788` into one dynamic array and expects four
bytes. Both `-g2017` and `-g2023` compiled and ran successfully, printing
`PASS: greedy unbounded streaming unpack`.

No gap or issue was identified, so an issue dedupe was not needed.

Command: `~/codex-supervisor/localrun 120 sh evidence/ieee1800-audit-c11g-20261020/attempt-01/run.sh`

Compiler source commit: `b9441bafbdb0b6b7413c09e0381845e69481391b`.
Icarus SHA-256: `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`.
VVP SHA-256: `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
Host: macOS Darwin ARM64. Elapsed: 0.20 s. Peak RSS: 16,842,752 bytes.

Compile and run logs for both editions are beside this file. Lead
classification remains pending because `ask-techlead --lead 1800-audit`
reported the daily cap reached (160).

# Focused `%p` reducer results (§21.2.1.7)

The focused reducer sources in `tests/1800_audit/c21/` were compiled and run in
both `-g2017` and `-g2023` modes. The paired outputs match:

```text
struct ['{sw:1, s:"hi"}]
enum [1]
assoc_int ['{3:7, 9:8}]
fixed ['{1, 2, 3}]
assoc_struct ['{10:?}]
```

The enum prints its numeric value instead of its name (#802); an associative
array of structs prints `?` for its element value (#801). The integral
associative-array, fixed-array, and direct-struct controls print values. Raw
per-edition localrun logs are beside this file. The issue-specific open and
closed dedupe results are in [`DEDUPE.md`](DEDUPE.md).

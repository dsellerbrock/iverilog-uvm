# Result — unpacked-structure open-array import

The fixed unpacked structure-array probe ran under Slurm job 3568 with the
pinned `cc25756d1` toolchain. Under both `-g2017` and `-g2023`, compilation
returned 0 while emitting:

```text
sorry: DPI import 'c_array_size': open array argument 'values' must have packed bit/logic or real elements; the call is skipped.
```

The C link succeeded; simulation then failed the explicit `svSize` assertion
because the import call was skipped. This is the same limitation observed for
`string[]` in job 3566. The C routine asks only for dimension and size; it
does not access the structure element or depend on its layout. Raw logs,
stdout, stderr, timestamps, toolchain versions, input copies, and hashes are
in [`remote-3568/`](remote-3568/).

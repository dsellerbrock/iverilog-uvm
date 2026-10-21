# Result — `string[]` open-array import

The minimal probe was run under Slurm job 3566 using pinned compiler
`cc25756d1` on DAN-DESKTOP. Both editions compiled with exit code 0, but the
compiler emitted this diagnostic and skipped the imported call:

```text
sorry: DPI import 'c_array_size': open array argument 'values' must have packed bit/logic or real elements; the call is skipped.
```

The C library linked successfully in both editions. At runtime, the skipped
call returned the default result and the probe terminated at its explicit
size assertion (`wrong DPI open-array size`) in both editions. Thus the test
was rejected as a legal `string[]` open-array use even though the simulator's
compile exit status was 0. Raw compiler logs, stdout, stderr, toolchain
versions, timing and hashes are in [`remote-3566/`](remote-3566/).

IEEE 1800-2017 and 1800-2023 §35.5.6.1 permit unsized unpacked dimensions on
imported function formals. Annex H.7.4 maps `string` to `const char *`; H.7.8
specifies C-compatible layout for unpacked aggregates whose elements are not
2-/4-state scalars or packed types. The probe asks only `svDimensions` and
`svSize`, not for element access. This is a candidate conformance gap for lead
classification and issue filing.

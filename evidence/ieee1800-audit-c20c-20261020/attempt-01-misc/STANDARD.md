# IEEE 1800 `$system` and `$stacktrace`

IEEE 1800-2017 §20.18.1 and IEEE 1800-2023 §20.17.1 define `$system` as calling C `system()`; it may be used as a task or function, and a function returns an `int`. The standard's phrase is “return value of the call to system() with data type int.” On POSIX, the C return is an encoded wait status, so `exit 3` is expected as 768. Each edition permits zero or one optional string argument; `n20_18_system_arity.sv` is the two-argument negative.

IEEE 1800-2023 §20.17.2 adds `$stacktrace`; its task form “displays the call stack information” and its function form “returns a string containing the call stack information.” The content is implementation-dependent, so the probe checks that the function result is nonempty and that the displayed trace contains `leaf`.

The local IEEE 1800-2017 PDF has no §20.17.2 or `$stacktrace`; rejecting the 2023-only task in `-g2017` is expected.

Text sources: local IEEE 1800-2017 §20.18.1, printed p. 623; local IEEE 1800-2023 §§20.17.1–20.17.2, printed pp. 652–653.

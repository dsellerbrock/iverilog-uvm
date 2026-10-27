# IEEE 1800 §§8.20 and 8.27 probes

This attempt contains two tasks selected by the 1800-audit lead:

1. Rerun the legal §8.20 method-specifier positive under `-g2023` only after the exact minimal correction noted below. The original standard text's Example 3 has `class base;` containing `pure virtual function f3`; both editions' §8.21 require a virtual class for that pure method. The source therefore uses `virtual class base;`, an editorial deviation needed to isolate the §8.20 specifier rules. All concrete descendants implement `f3` before construction.
2. Probe §8.27 forward class typedefs, including a forward-declared parameterized class. The positive must print `FWD 2 1 8` under both `-g2017` and `-g2023`; an unresolved forward typedef must fail in both editions.

Each compiler and runtime invocation has a 30-second timeout. Open+closed dedupe for §8.27 is in `dedupe-open-closed.txt`; #760 is inspected in `issue-760-reread.txt`.

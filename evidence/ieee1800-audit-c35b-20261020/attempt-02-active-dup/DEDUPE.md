# §35.4 duplicate `c_identifier` issue dedupe

Searched the repository's open and closed GitHub issues with each term named
by the audit lead: `"export task"`, `"svIsDisabledState"`,
`"svAckDisabledState"`, `"disable DPI"`, `"c_identifier"`, and `"35.9"`.
For the signature-conflict candidate, also searched open and closed issues for
`"35.4"`, `"DPI signature"`, `"duplicate import"`, and
`"same c_identifier"`. Full JSON results are beside this file.

The searches found no open or closed direct report for importing the same C
linkage name with incompatible signatures. Closed #13 is a broad DPI
completeness phase covering task imports, exports, and several ABI features,
but its explicit scope does not include global name uniqueness or signature
consistency. Its closure therefore does not duplicate this finding. Open #823
and #824 concern interface modport task exports, not the Clause 35.4 linkage
namespace. Closed #157 concerns a null pointer in UVM regex DPI code.
Closed #19 only mentions a struct in a DPI argument. Closed #474 and open #817
are unrelated SystemVerilog duplicate or package-import diagnostics; these
were surfaced by the supplemental `"DPI signature"` and
`"duplicate import"` searches and inspected.

The issue candidate is based on the active-call negative reproducer in
[`RESULT.md`](RESULT.md), which returned compile success in both editions.
No issue has been opened because the audit lead is the designated filer and
`ask-techlead --lead 1800-audit` currently reports the daily cap reached.

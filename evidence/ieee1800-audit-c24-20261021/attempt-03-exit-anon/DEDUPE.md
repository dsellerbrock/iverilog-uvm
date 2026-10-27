# Open and closed issue dedupe

Queried `dsellerbrock/iverilog-uvm` with `gh issue list --state all --search '<term> in:title,body'`. This searches both open and closed issues.

| Search | Matches relevant to this probe |
| --- | --- |
| `"$exit"` | Open #786 directly covers `$exit` called in a program. Its expected `PROG2 done` output conflicts with §24.7, which requires `$exit` to terminate all initial procedures in the originating program. Other matches are unrelated. |
| `"anonymous program"` | None |
| `anonymous program package` | None |
| `programwide task` | None |
| `"program-wide" task` | None |
| `program in package` | #773 and #841 are unrelated package-scope `let` and external-constraint issues. |
| `unnamed program` | None |
| `"program;" "endprogram"` | #786 is the same `$exit` issue; #17 is broad closed program-block history. |
| `"program termination"` | None |
| `"24.6"` / `"24.7"` | None |

Conclusion for dedupe: the `$exit` behavior is already represented by #786 and needs lead review against §24.7; no new `$exit` issue was filed. The anonymous-program syntax failure has no direct open or closed match in these searches. The module-reference control did not reach the relevant source construct and is not a separate finding.

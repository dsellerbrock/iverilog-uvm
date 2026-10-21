# Open/closed issue dedupe refresh

Repository: `dsellerbrock/iverilog-uvm`. Date: 2026-10-20. For each row below,
the issue tracker was searched separately in `open` and `closed` states with
the recorded GitHub CLI query. Raw JSON results and SHA-256 hashes are in the
matching `issue-N/` directory. The issue itself appearing in the open results
is expected; other hits were checked for an overlapping report.

| Issue | Search phrase | Open hits | Closed hits | Dedupe assessment |
|---|---|---|---|---|
| [#785](https://github.com/dsellerbrock/iverilog-uvm/issues/785) | `"$bitstoreal" constant` | #785 | none | No other issue reports real/vector conversion system functions being rejected in constant expressions. |
| [#786](https://github.com/dsellerbrock/iverilog-uvm/issues/786) | `"$exit" program` | #786, #807 | #17 | #807 is an unrelated VCD dump gap. Closed #17 covers `$exit` as program termination, not the required wait for active program blocks to complete. |
| [#787](https://github.com/dsellerbrock/iverilog-uvm/issues/787) | `"$finish(2)" statistics` | #787 | none | No other issue reports missing memory/CPU statistics for `$finish(2)`. |
| [#788](https://github.com/dsellerbrock/iverilog-uvm/issues/788) | `"$bits" unpacked struct` | #788, #819, #675, #750, #861, #818, #757 | #499 | Reviewed the broad hits: #499 is packed-bit selection after an unpacked struct member; the other open hits concern net types, `rand_mode`, casts, conditional operands, ports, or type matching. None covers `$bits` of an unpacked struct type/variable. |
| [#789](https://github.com/dsellerbrock/iverilog-uvm/issues/789) | `"$typename" packed range` | #789 | none | No other issue reports omission of a typedef-named packed vector's range from `$typename`. |
| [#790](https://github.com/dsellerbrock/iverilog-uvm/issues/790) | `"$typename" struct member package` | #790, #791 | none | #791 is a separate `$typename` string-format/name-generation gap; #790 is compile-time rejection of a legal struct member that collides with a package name. |
| [#791](https://github.com/dsellerbrock/iverilog-uvm/issues/791) | `"$typename" enum struct` | #791, #790 | none | #790 concerns struct-member parsing, not generated enum names, scope prefixes, or whitespace in `$typename` output. |
| [#795](https://github.com/dsellerbrock/iverilog-uvm/issues/795) | `"$countbits" variable control` | #795 | none | No other issue reports the runtime abort for variable control bits in `$countbits`. |
| [#796](https://github.com/dsellerbrock/iverilog-uvm/issues/796) | `"$error" elaboration formatted` | #796 | #27 | Closed #27 is an OpenTitan compile-progress/runtime-stub report and does not cover formatted elaboration-time severity tasks. |
| [#803](https://github.com/dsellerbrock/iverilog-uvm/issues/803) | `"$readmemh" associative array` | #803, #804 | none | #804 is separate enum-value range validation; #803 concerns associative-array arguments to `$readmemh`/`$writememh`. |
| [#804](https://github.com/dsellerbrock/iverilog-uvm/issues/804) | `"readmemh" enum range` | #804 | none | #803 concerns unsupported associative-array arguments; it does not report missing out-of-range enum-value diagnostics. |

<a id="issue-785-dedupe"></a>
### Issue #785 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

<a id="issue-786-dedupe"></a>
### Issue #786 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

<a id="issue-787-dedupe"></a>
### Issue #787 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

<a id="issue-788-dedupe"></a>
### Issue #788 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

<a id="issue-789-dedupe"></a>
### Issue #789 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

<a id="issue-790-dedupe"></a>
### Issue #790 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

<a id="issue-791-dedupe"></a>
### Issue #791 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

<a id="issue-795-dedupe"></a>
### Issue #795 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

<a id="issue-796-dedupe"></a>
### Issue #796 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

<a id="issue-803-dedupe"></a>
### Issue #803 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

<a id="issue-804-dedupe"></a>
### Issue #804 dedupe

See the table's search phrase, open/closed hits, and overlap assessment.

Searches were rerun as current-state checks after the original issue filing.
The original probes and normative analyses remain linked from each issue row
in `docs/conformance/matrices/ieee1800_status.md`.

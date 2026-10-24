# Lead filing brief — §35.4 duplicate DPI linkage signature

**Proposed title:** `[IEEE 1800] §35.4 — duplicate DPI c_identifier with incompatible signatures is accepted`

**Normative basis:** IEEE 1800-2017 and IEEE 1800-2023 §35.4 require global
import/export linkage names to be unique without overloading, and require all
declarations using a given `c_identifier` to have exactly the same type
signature.

**Minimal reproducer:**

```systemverilog
module n35_dup_c_identifier;
  import "DPI-C" c_add2 = function int f1(int a, int b);
  import "DPI-C" c_add2 = function real f2(real a);
  initial begin
    $display("I1 %0d", f1(3, 4));
    $display("I2 %0.1f", f2(2.0));
  end
endmodule
```

**Command and result:** Using Icarus `cc25756d1`, both
`iverilog -g2017 -o n35.out n35_dup_c_identifier.sv` and the corresponding
`-g2023` command return 0 with no diagnostic. Both imported functions are
referenced. Expected result: compile-time error for incompatible declarations
sharing `c_add2`.

**Dedupe:** Open and closed searches for `"c_identifier"`, `"35.4"`,
`"DPI signature"`, `"duplicate import"`, `"same c_identifier"`, and the
lead's six requested DPI/disable terms found no direct duplicate. Closed #13
covers broader DPI tasks/exports but not linkage-name uniqueness or signature
consistency. See [`DEDUPE.md`](DEDUPE.md) and the saved JSON results.

The lead remains the designated issue filer. The helper currently reports
160/160 used. No issue was opened from this brief.

On 2026-10-20 the user reported a lead-cap reset to 80 calls remaining. The
next fresh-context `--lead 1800-audit` request (matrix summary plus current
open-issue inventory) still returned `tech lead daily lead cap reached
(160)`. The runner did not edit supervisor files and did not file the issue;
classification and filing remain pending with the lead.

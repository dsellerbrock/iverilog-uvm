# Lead review draft — not filed

## Title

[IEEE 1800] §23.3.3 — reject mismatched user-defined nettypes on port connections

## Reproducer

```systemverilog
package n06_22_nonmatching_nettypes;
  nettype logic [3:0] first_nt;
  nettype logic [3:0] second_nt;
endpackage

import n06_22_nonmatching_nettypes::*;
module sink(input first_nt data);
endmodule
module top;
  second_nt other;
  sink u0(other);
endmodule
```

Expected: elaboration rejects connecting `second_nt` to a `first_nt` input.
Observed: Icarus 13.0-devel accepts the negative compile in both `-g2017`
and `-g2023`. The matching-nettype and alias positive controls compile and
run in both editions.

IEEE 1800-2017/2023 §23.3.3 requires matching nettypes when both sides use
user-defined nettypes. The standards text was rechecked against both local
PDFs; the verification and exact open/closed dedupe are recorded in `README.md`.

## Evidence and dedupe

- Probe source: `tests/1800_audit/c06/n06_22c_nonmatching_nettypes.sv`.
- Raw results and tool hashes: `results-attempt-04/` and `README.md`.
- Current open-and-closed search: `dedupe-live-20261020.txt`.
- No direct issue match. #435 is about class-method resolution functions;
  #492 is about unpacked-array output ports; neither covers this mismatch.

The lead must classify and file this if it agrees the probe demonstrates a
new gap. This draft has not been posted.

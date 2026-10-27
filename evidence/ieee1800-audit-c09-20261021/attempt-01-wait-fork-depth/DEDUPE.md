# §9.6.1 `wait fork` depth-probe issue dedupe

Source: all 409 open and closed issues in `dsellerbrock/iverilog-uvm`, fetched
2026-10-21 with `gh issue list --state all --limit 1000`; title and body scanned.

- `wait fork`: #643 OPEN (the immediate-child versus descendant defect); #47
  CLOSED (unrelated warning-noise cleanup).
- `9.6.1`: #643 OPEN; #508, #509 and #511 CLOSED, all Clause 19 cross-bin
  issues with no relation to §9.6.1.
- `grandchild`: no hits. #643 is titled with “descendants” and contains the
  same immediate-child requirement; it is the exact existing issue.
- `#643`: no literal hits in titles/bodies, including the issue itself.

The seven cases deepen existing #643. No new issue is planned.

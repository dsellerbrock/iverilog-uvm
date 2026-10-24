# §13.8 static-method expression-context issue dedupe

Source: all 409 open and closed issues in `dsellerbrock/iverilog-uvm`, fetched
2026-10-21 with `gh issue list --state all --limit 1000`. Search terms in both
title and body: `static method call in a continuous assignment`, `class static
method`, `13.8`, `static method continuous`, `internal error`, and `#642`.

The exact existing issue is #642 (OPEN), “§13.8 — Class static method call in a
continuous assignment fails with an internal error.” The phrase searches
`static method call in a continuous assignment`, `class static method`, and
`13.8` each found only #642; the broader `internal error` search found #642,
#795, and #818. Searching `#642` also matched #846's reference to that number.

Because S5 failed in a port connection, a focused search over the same 409
issues used `port expression too complicated`, `class static method port
connection`, `static method input port`, `method call in port expression`, and
`class-qualified call port`; all returned zero hits. The lead will determine
whether the S5 failure is within #642's scope or a distinct issue.

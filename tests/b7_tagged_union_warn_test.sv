// Phase 63b / B7: tagged-union direct member assignment.
//
// Earlier this test only verified an advisory warning fired.  The
// advisory is now obsolete: tag enforcement was implemented in
// commit cfc4e7cfb via the companion-tag NetNet approach.  Updated
// to verify direct member access (u.member = val) compiles and
// roundtrips for an unpacked tagged union with mixed-width members.
`timescale 1ns/1ps

module top;
  typedef union tagged {
    int   a;
    real  b;
    logic [7:0] c;
  } my_tu;

  initial begin
    my_tu u;
    u.a = 42;
    if (u.a != 42) $fatal(1, "FAIL: read-back");
    $display("PASS: tagged union compiles with mixed-width members");
    $finish;
  end
endmodule

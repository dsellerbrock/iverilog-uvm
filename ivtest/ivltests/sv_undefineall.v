`define REMOVE_ME
`define ALSO_REMOVE_ME 1

module test;
  initial begin
`ifdef REMOVE_ME
    $display("PASS: REMOVE_ME defined before directive");
`else
    $display("FAIL: REMOVE_ME missing before directive");
`endif
`undefineall
`ifdef REMOVE_ME
    $display("FAIL: REMOVE_ME remains defined");
`else
    $display("PASS: REMOVE_ME undefined");
`endif
`ifdef ALSO_REMOVE_ME
    $display("FAIL: ALSO_REMOVE_ME remains defined");
`else
    $display("PASS: ALSO_REMOVE_ME undefined");
`endif
    $display("PASS: line %0d", `__LINE__);
    $display("PASSED");
  end
endmodule

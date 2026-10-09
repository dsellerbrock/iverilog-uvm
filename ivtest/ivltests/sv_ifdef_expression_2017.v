`define CONTROL

module test;
  initial begin
`ifdef CONTROL
    $display("PASS");
`else
    $display("FAIL: plain identifier `ifdef");
`endif
  end
endmodule

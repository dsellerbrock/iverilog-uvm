`define WORD 1
`define JOIN(a,b) a``b
module tb;
  localparam integer value_1 = 42;
  initial begin
    if (`JOIN(value_,1) != 42) $fatal(1, "macro-body paste");
    if (``WORD != "1") $fatal(1, "compatibility stringify");
    $display("PASSED");
  end
endmodule

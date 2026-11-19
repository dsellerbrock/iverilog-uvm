module issue705_cycle_delay;
  parameter int COUNT = 0;
  bit clk = 0;
  always #5 clk = !clk;
  default clocking cb @(posedge clk); endclocking

`ifdef ISSUE705_UNKNOWN
  logic [31:0] count;
`else
  int count;
`endif
  initial begin
    #2;
`ifdef ISSUE705_UNKNOWN
    count = 32'h1x;
`else
    count = COUNT;
`endif
    ##(count) $display("Attached statement at %0t", $time);
    $finish(0);
  end
  initial #20 $fatal(1, "cycle delay did not finish");
endmodule

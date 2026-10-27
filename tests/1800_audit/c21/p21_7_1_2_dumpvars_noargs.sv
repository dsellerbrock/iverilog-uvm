module leaf;
  logic a = 1'b0;
  logic b = 1'b1;
  initial #1 a = 1'b1;
endmodule

module top;
  logic root_value = 1'b0;
  leaf u();
  initial begin
    $dumpfile("dumpvars_noargs.vcd");
    $dumpvars;
    #2 $finish;
  end
endmodule

module leaf;
  logic a = 1'b0;
  logic b = 1'b1;
  initial begin
    #1;
    a = 1'b1;
    b = 1'b0;
  end
endmodule

module top;
  logic root_value = 1'b0;
  leaf u1();
  leaf u2();
  initial begin
    $dumpfile("dumpvars_selectors.vcd");
    $dumpvars(0, u1, u2.b);
    #2 $finish;
  end
endmodule

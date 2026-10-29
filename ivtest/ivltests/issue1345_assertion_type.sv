module issue1345_assertion_type;
  logic clk = 0, a = 1;
  always #5 clk = ~clk;
  ap1: assert property (@(posedge clk) a);
  as1: assume property (@(posedge clk) a);
  cp1: cover property (@(posedge clk) a);
  initial begin
    #1 $check_assertion_types;
    $finish;
  end
endmodule

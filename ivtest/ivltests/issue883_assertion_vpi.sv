module issue883_assertion_vpi;
  logic clk = 0;
  always #5 clk = ~clk;

  ap: assert property (@(posedge clk) 1'b1);

  initial begin
    #1 $check_assertion_vpi;
    $finish;
  end
endmodule

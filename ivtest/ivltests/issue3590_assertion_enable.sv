module top;
  bit clk = 0, ok = 1;
  int target_pass = 0, target_fail = 0, other_pass = 0;
  always #5 clk = ~clk;
  target: assert property (@(posedge clk) 1'b1 ##1 ok)
    target_pass++; else target_fail++;
  other: assert property (@(posedge clk) 1'b1)
    other_pass++; else $display("ERROR: other failed");
  initial begin
    #1 $setup3590;
    #6 $disable3590; $disable3590;
    #15 ok = 0; $enable3590; $enable3590;
    #15;
    $check3590;
    if (target_pass != 1 || target_fail != 1 || other_pass != 4)
      $display("ERROR: actions target=%0d/%0d other=%0d", target_pass, target_fail, other_pass);
    else $display("Action counts OK");
    $finish;
  end
endmodule

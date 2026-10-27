module issue1194_always_assertion;
  logic clk = 0, a = 0;
  int plain_fail = 0, always_fail = 0;

  always #5 clk = ~clk;
  p: assert property (@(posedge clk) a) else plain_fail++;
  always assert property (@(posedge clk) a) else always_fail++;

  initial begin
    #16;
    $display("plain=%0d always=%0d", plain_fail, always_fail);
    $finish;
  end
endmodule

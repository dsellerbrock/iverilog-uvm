module ff(input clk, input d, output reg q);
  reg notifier = 0;
  always @(posedge clk) q <= d;
  specify
    $setup(d, posedge clk, 3, notifier);
    $hold(posedge clk, d, 2, notifier);
    $width(posedge clk, 4, 0, notifier);
  endspecify
endmodule

module p31_tchk;
  reg clk = 0, d = 0;
  wire q;
  integer nc = 0;
  ff u(clk, d, q);
  always @(u.notifier) nc++;
  initial begin
    #9  d = 1;          // t9
    #1  clk = 1;        // t10: setup violation (1 < 3)
    #1  d = 0;          // t11: hold violation (1 < 2)
    #4  clk = 0;        // t15
    #5  clk = 1;        // t20
    #2  clk = 0;        // t22: width violation (high pulse 2 < 4)
    #10 $display("N %0d %b", nc, u.notifier);   // 3 1
  end
endmodule

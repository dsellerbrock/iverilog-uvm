// The legal forms of the 16.12.11 / 16.12.13 ranges still compile and run.
module issue3005_property_range;
  bit clk = 0, a = 1;
  always #5 clk = ~clk;
  a1: assert property (@(posedge clk) always [2:$] (a)) else $display("a1 fail %0t", $time);
  a2: assert property (@(posedge clk) s_always [2:3] (a)) else $display("a2 fail %0t", $time);
  a3: assert property (@(posedge clk) s_eventually [0:$] (a));
  a4: assert property (@(posedge clk) eventually [1:2] (a)) else $display("a4 fail %0t", $time);
  initial begin
    #42 a = 0;
    #10 a = 1;
    #40 $display("done");
    $finish;
  end
endmodule

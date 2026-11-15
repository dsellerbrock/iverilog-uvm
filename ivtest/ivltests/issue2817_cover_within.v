// Issue #2817: IEEE 1800-2017/2023 16.9.10, 16.14.3. A cover of a `within'
// sequence runs its pass statement for each matching window. b is high only
// at the edge at 25, so the windows that start at 5, 15 and 25 contain it.
module issue2817_cover_within;
  bit clk = 0; always #5 clk = ~clk;
  bit b;
  c1: cover property (@(posedge clk) b within (1 ##4 1)) $display("cover match %0t", $time);
  c2: cover sequence (@(posedge clk) b within (1 ##4 1)) $display("cover seq %0t", $time);
  a1: assert property (@(posedge clk) b within (1 ##4 1)) $display("pass %0t", $time); else $display("fail %0t", $time);
  initial begin b = 0; #20 b = 1; #10 b = 0; #60 $finish; end
endmodule

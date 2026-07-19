// M9-NFA dual-run seed: plain fixed-delay chains (op 0) through the
// automaton engine; verdict parity with the legacy linear engine.
module plain_fixed;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;

  p1: assert property (@(posedge clk) a ##1 b)
        $display("p1 PASS at %0t", $time);
        else $display("p1 FAIL at %0t", $time);
  p2: assert property (@(posedge clk) a ##2 b ##1 c)
        else $display("p2 FAIL at %0t", $time);

  initial begin
    @(negedge clk) a = 1; b = 1; c = 1;   // hold everything true
    repeat (3) @(negedge clk);
    b = 0;                                 // b=0 @45+: fails arrive
    repeat (2) @(negedge clk);
    b = 1; a = 0;                          // stop new attempts
    repeat (4) @(negedge clk);
    $finish(0);
  end
endmodule

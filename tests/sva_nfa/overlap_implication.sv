// M9-NFA dual-run seed: overlapped |-> consequents (##0 fusion —
// conjunction guards) including a windowed overlap start.
module overlap_implication;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;
  v1: assert property (@(posedge clk) a |-> b)
        $display("v1 PASS at %0t", $time);
        else $display("v1 FAIL at %0t", $time);
  v2: assert property (@(posedge clk) a |-> b ##1 c)
        $display("v2 PASS at %0t", $time);
        else $display("v2 FAIL at %0t", $time);
  v3: assert property (@(posedge clk) a |-> ##[0:2] b)
        $display("v3 PASS at %0t", $time);
        else $display("v3 FAIL at %0t", $time);
  initial begin
    @(negedge clk) a = 1; b = 1;     // a,b@15: v1 pass; v2 needs c@25; v3 pass@15
    @(negedge clk) a = 0; b = 0; c = 1;  // c@25: v2 pass@25
    @(negedge clk) c = 0;
    @(negedge clk) a = 1;            // a@45,b=0: v1 FAIL@45; v2 dies@45; v3 window b@45/55/65
    @(negedge clk) a = 0;
    @(negedge clk) b = 1;            // b@65: v3 pass@65 (last window slot)
    @(negedge clk) b = 0; a = 1;     // a@75: v1 FAIL; v3 window 75..95
    @(negedge clk) a = 0;
    repeat (2) @(negedge clk);       // no b: v3 FAIL@95
    @(negedge clk);
    $finish(0);
  end
endmodule

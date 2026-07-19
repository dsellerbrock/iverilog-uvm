// M9-NFA dual-run seed: not (op 3) — a match is the failure; a failed
// match is silent (legacy parity).
module negation;
  logic clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;

  n1: assert property (@(posedge clk) not (a ##1 b))
        else $display("n1 FAIL at %0t", $time);

  initial begin
    @(negedge clk) a = 1;            // a@15
    @(negedge clk) a = 0; b = 1;     // b@25: match -> FAIL@25
    @(negedge clk) b = 0;
    @(negedge clk) a = 1;            // a@45
    @(negedge clk) a = 0;            // b@55=0: no match, silent
    @(negedge clk);
    $finish(0);
  end
endmodule

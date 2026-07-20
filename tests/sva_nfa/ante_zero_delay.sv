// M9-NFA dual-run seed: mid-##0 antecedents — the completion tick
// carries a guard conjunction (trailing ##0-fused run), and the
// obligation must arm on p&&q, not q alone (a lone q must stay
// vacuous).
module ante_zero_delay;
  logic clk = 0, p = 0, q = 0, r = 0, x = 0, y = 0, z = 0, u = 0;
  always #5 clk = ~clk;

  a1: assert property (@(posedge clk) p ##0 q |=> r)
        $display("a1 PASS at %0t", $time);
        else $display("a1 FAIL at %0t", $time);
  a2: assert property (@(posedge clk) x ##1 y ##0 z |-> ##1 u)
        $display("a2 PASS at %0t", $time);
        else $display("a2 FAIL at %0t", $time);

  initial begin
    @(negedge clk) p = 1; q = 1;      // p,q@15 -> r@25?
    @(negedge clk) p = 0; q = 0; r = 1;  // r@25: a1 PASS@25
    @(negedge clk) r = 0; p = 1;      // p@35 alone: vacuous
    @(negedge clk) p = 0; q = 1;      // q@45 alone: vacuous
    @(negedge clk) q = 0; p = 1; q = 1;  // p,q@55 -> r@65?
    @(negedge clk) p = 0; q = 0;      // r@65=0: a1 FAIL@65
    @(negedge clk) x = 1;             // x@75
    @(negedge clk) x = 0; y = 1; z = 1;  // y,z@85 fused -> u@95?
    @(negedge clk) y = 0; z = 0; u = 1;  // u@95: a2 PASS@95
    @(negedge clk) u = 0; x = 1;      // x@105
    @(negedge clk) x = 0; y = 1;      // y@115, z=0: ante dies, vacuous
    @(negedge clk);
    $finish(0);
  end
endmodule

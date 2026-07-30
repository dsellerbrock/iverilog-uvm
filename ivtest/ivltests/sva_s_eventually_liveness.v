// A STRONG liveness obligation re-arms on every attempt. `assert
// property' starts an attempt each tick, and an attempt beginning at
// tick t needs p at some tick >= t -- so the obligation window SHRINKS
// and later attempts are strictly harder, never implied by an earlier
// one.
//
// This used to lower as "was p EVER seen", reporting only if p never
// held at all. With p true once early and never again, every later
// attempt is undischargeable and yet NOTHING was reported -- a real
// liveness violation vanished. The same property spelled
// `1'b1 |-> s_eventually(p)' (a different op_type) DID report it, so
// two spellings of one property disagreed. Both engines shared the bug.
//
// v1/v2 are the minimal pair and must now agree; s1 pins that the fix
// did not simply make the operator always fail.
module sva_s_eventually_liveness;
  logic clk = 0, b = 0, c = 0;
  int v1_f = 0, v2_f = 0, s1_f = 0;
  always #5 clk = ~clk;

  v1: assert property (@(posedge clk) s_eventually b)          else v1_f++;
  v2: assert property (@(posedge clk) 1'b1 |-> s_eventually(b)) else v2_f++;
  s1: assert property (@(posedge clk) s_eventually c)          else s1_f++;

  final begin
    if (v1_f == v2_f && v1_f > 0 && s1_f == 0)
      $display("PASSED");
    else
      $display("FAILED v1_f=%0d v2_f=%0d s1_f=%0d (want v1_f==v2_f>0, s1_f==0)",
               v1_f, v2_f, s1_f);
  end

  initial begin
    @(negedge clk) b = 1;
    @(negedge clk) b = 0;
    repeat (4) @(negedge clk);
    c = 1;                       // c holds through to the end
    @(negedge clk);
    $finish(0);
  end
endmodule

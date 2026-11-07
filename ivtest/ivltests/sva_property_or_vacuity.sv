// IEEE 1800-2023 16.12.4 / 16.14.8(e): vacuity of `P1 or P2'. An attempt is
// nonvacuous iff an operand attempt is, whether that operand passed or
// failed (a failed sequence is nonvacuous, 16.14.8 a). User ruling
// 2026-11-06: when one operand decides the `or' while the other is still
// running, the success is reported then, and only the finished operands
// count for vacuity. The VPI module logs P<time> for a nonvacuous success
// and V<time> for a vacuous one (F<time> for a failure).
//   tick (time)  a b c d e g
//   0 (5)        0 0 1 0 1 1   o1/o2: a|->b vacuous, c|->##3 d running -> V5
//   1 (15)       1 1 1 0 1 0   o1/o2: a|->b passes, other running -> P15
//   2 (25)       1 0 1 0 0 0   o1/o2: decided at 55 by d; o3: e fails,
//                              c ##1 g |-> d vacuous at 35 -> P35
//   3 (35)       0 0 0 1 0 0   o1/o2: both vacuous -> V35; o3: e fails -> P35
//   4 (45)       1 0 0 1 1 1   o1/o2: a|->b fails, c|->.. vacuous -> P45
//   5..7         see va..vg
module sva_property_or_vacuity;
  bit clk = 0;
  bit a, b, c, d, e, g;
  bit va[8] = '{0,1,1,0,1,0,0,0}, vb[8] = '{0,1,0,0,0,0,0,0},
      vc[8] = '{1,1,1,0,0,0,0,0}, vd[8] = '{0,0,0,1,1,1,0,0},
      ve[8] = '{1,1,0,0,1,1,0,0}, vg[8] = '{1,0,0,0,1,0,0,0};

  always #5 clk = ~clk;

  o1: assert property (@(posedge clk) (a |-> b) or (c |-> ##3 d));
  o2: assert property (@(posedge clk) (c |-> ##3 d) or (a |-> b));
  o3: assert property (@(posedge clk) e or (c ##1 g |-> d));

  initial begin
    $vac_setup;
    {a, b, c, d, e, g} = {va[0], vb[0], vc[0], vd[0], ve[0], vg[0]};
    for (int k = 1; k < 8; k++)
      @(negedge clk) {a, b, c, d, e, g} = {va[k], vb[k], vc[k], vd[k], ve[k], vg[k]};
    @(posedge clk);
    #1 $vac_dump;
    $finish;
  end
endmodule

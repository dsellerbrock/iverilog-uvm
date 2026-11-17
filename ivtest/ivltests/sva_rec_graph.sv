// IEEE 1800-2023 16.12.17 / F.7: the standard's legal recursive properties
// evaluated by the recursion pool. An attempt of a recursive property is
// true iff every finite approximation of it is (F.7), so a pending
// recursion never fails by itself.
// al (prop_always): a is 0 only at 45, so attempts 5..45 all fail at 45;
//   later attempts stay pending.
// wu (prop_weak_until): attempts 5..25 are discharged by q at 25; attempts
//   35 and 45 meet a = 0 before q, and fail at 45.
// ph (check_phase1/check_phase2, mutual recursion, check_phase2 declared
//   after its first use): s1, s2 hold from 55; the attempt at 55 hands over
//   to check_phase2 at 65, where ph2 is 0.
// l3 (legal_3: disable iff over prop_always): attempts 5..45 fail at 45;
//   later attempts are pending when rst disables them at 85.
module sva_rec_graph;
  logic clk = 0, a = 1, q = 0, s1 = 0, s2 = 0, ph1 = 1, ph2 = 1, rst = 0;
  always #5 clk = ~clk;
  property prop_always(p);
    p and (1'b1 |=> prop_always(p));
  endproperty
  property prop_weak_until(p, r);
    r or (p and (1'b1 |=> prop_weak_until(p, r)));
  endproperty
  property check_phase1;
    s1 |-> (ph1 and (1'b1 |=> check_phase2));
  endproperty
  ph: assert property (@(posedge clk) check_phase1)
    else $display("%0t ph fail", $time);
  property check_phase2;
    s2 |-> (ph2 and (1'b1 |=> check_phase1));
  endproperty
  property legal_3(p);
    disable iff (rst) prop_always(p);
  endproperty
  al: assert property (@(posedge clk) prop_always(a))
    else $display("%0t al fail", $time);
  wu: assert property (@(posedge clk) prop_weak_until(a, q))
    else $display("%0t wu fail", $time);
  l3: assert property (@(posedge clk) legal_3(a))
    else $display("%0t l3 fail", $time);
  initial begin
    #20 q = 1;          // q sampled 1 at 25
    #10 q = 0;
    #10 a = 0;          // a sampled 0 at 45 only
    #10 a = 1;
    s1 = 1; s2 = 1;     // s1, s2 sampled 1 from 55
    #10 ph2 = 0;        // ph2 sampled 0 at 65 only
    #10 ph2 = 1;
    #10 rst = 1;        // rst sampled 1 from 85
    #20 $display("done");
    $finish;
  end
endmodule

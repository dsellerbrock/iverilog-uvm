`timescale 1ns/1ns
module issue3979_sequence_actual;
  bit clk, a, b, c, d, r, s, u, v;
  always #5 clk = !clk;

  int reports[19], events[3];
  bit [63:0] event_ticks[3];

  task automatic verdict(int id, bit passed, bit expected, time tick);
    if (passed != expected || $time != tick)
      $fatal(1, "case %0d pass=%b at %0t, expected %b at %0t",
             id, passed, $time, expected, tick);
    reports[id]++;
  endtask

  task automatic record_event(int id);
    events[id]++;
    event_ticks[id] |= 64'd1 << $time;
  endtask

  property p(sequence q, logic result);
    q |-> result;
  endproperty

  property defaulted(sequence q = (a ##1 b) or (a ##2 c));
    q |-> d;
  endproperty

  property combined(sequence q);
    (q and (a ##2 c)) |-> 1'b1;
  endproperty

  property intersected(sequence q);
    (q intersect (a ##1 b)) |-> d;
  endproperty

  property property_and(untyped p_arg, sequence q);
    p_arg and q;
  endproperty

  property nonoverlap(sequence q);
    q |=> d;
  endproperty

  property twice(sequence q);
    q ##1 q |-> 1'b1;
  endproperty

  property forwarded(sequence q);
    p(q, d) or 1'b0;
  endproperty

  property untyped_operand(untyped q);
    q;
  endproperty

  property forwarded_operand(property q);
    untyped_operand(q or (a ##2 c));
  endproperty

  property clocked(event e = u or v);
    @(e) 1'b1;
  endproperty

  property untyped_clocked(untyped e);
    @(e) 1'b1;
  endproperty

  // One attempt starts at 5. The first consequent succeeds, while the
  // second fails. Neither the name nor an early match can end the attempt.
  bound_fail: assert property (@(posedge clk) p((a ##1 b) or (a ##2 c), d))
    verdict(0, 1, 0, 25); else verdict(0, 0, 0, 25);
  direct_fail: assert property (@(posedge clk) ((a ##1 b) or (a ##2 c)) |-> d)
    verdict(1, 1, 0, 25); else verdict(1, 0, 0, 25);
  bound_pass: assert property (@(posedge clk) p(.q((a ##1 b) or (a ##2 c)), .result(1'b1)))
    verdict(2, 1, 1, 25); else verdict(2, 0, 1, 25);
  direct_pass: assert property (@(posedge clk) ((a ##1 b) or (a ##2 c)) |-> 1'b1)
    verdict(3, 1, 1, 25); else verdict(3, 0, 1, 25);
  bound_default: assert property (@(posedge clk) defaulted())
    verdict(4, 1, 0, 25); else verdict(4, 0, 0, 25);

  // The operands following 'or' include both a temporal group and a
  // plain expression. First-match and repetition expose different ends.
  late_or: assert property (@(posedge clk) p(a or (a ##2 c), 1'b1))
    verdict(5, 1, 1, 25); else verdict(5, 0, 1, 25);
  first_only: assert property (@(posedge clk) p(first_match(((a ##1 b) or (a ##2 c))), d))
    verdict(6, 1, 1, 15); else verdict(6, 0, 1, 15);
  repeated: assert property (@(posedge clk) p((r ##1 s)[*2], 1'b1))
    verdict(7, 1, 1, 35); else verdict(7, 0, 1, 35);
  simple_repeat: assert property (@(posedge clk) p(a[*1], 1'b1))
    verdict(8, 1, 1, 5); else verdict(8, 0, 1, 5);
  nested_comb: assert property (@(posedge clk) combined((a ##1 b) or (a ##2 c)))
    verdict(9, 1, 1, 25); else verdict(9, 0, 1, 25);
  matched_interval: assert property (@(posedge clk) intersected((a ##1 b) or (a ##2 c)))
    verdict(11, 1, 1, 15); else verdict(11, 0, 1, 15);
  rebound_and: assert property (@(posedge clk) if (a)
                               property_and(a |-> ##1 d, (a ##1 b) or (a ##2 c)))
    verdict(12, 1, 1, 15); else verdict(12, 0, 1, 15);
  // An empty |=> endpoint starts the consequent on the same tick.
  empty_branch: assert property (@(posedge clk) if (a) nonoverlap(a[*0] or (a ##1 b)))
    verdict(13, 1, 0, 5); else verdict(13, 0, 0, 5);
  reused_group: assert property (@(posedge clk) twice((r ##1 s)[*1]))
    verdict(14, 1, 1, 35); else verdict(14, 0, 1, 35);
  ranged_repeat: assert property (@(posedge clk) if (a) p((r ##1 s)[*1:2], 1'b1))
    verdict(15, 1, 1, 35); else verdict(15, 0, 1, 35);
  ranged_direct: assert property (@(posedge clk) if (a) (r ##1 s)[*1:2] |-> 1'b1)
    verdict(16, 1, 1, 35); else verdict(16, 0, 1, 35);
  forwarded_or: assert property (@(posedge clk) if (a)
                                forwarded((a ##1 b) or (a ##2 c)))
    verdict(17, 1, 0, 25); else verdict(17, 0, 0, 25);
  forwarded_kind: assert property (@(posedge clk) if (a) forwarded_operand(a |-> ##1 d))
    verdict(18, 1, 1, 15); else verdict(18, 0, 1, 15);

  // The same unguarded 'or' selects Boolean sequence matching on clk
  // or an event on each operand transition, even while u || v stays high.
  seq_or: assert property (@(posedge clk) p(u or v, 1'b1))
    verdict(10, 1, 1, 5); else verdict(10, 0, 1, 5);
  ev_or: assert property (clocked(((u or v)))) record_event(0);
    else $fatal(1, "event actual failed");
  ev_default: assert property (clocked()) record_event(1);
    else $fatal(1, "event default failed");
  ev_untyped: assert property (untyped_clocked((u or v))) record_event(2);
    else $fatal(1, "untyped event actual failed");

  initial begin
    $assertvacuousoff(0);
    a = 1; r = 1;
    #2 u = 1;
    #2 v = 1;
    #2 u = 0;
    #2 v = 0;
    #2 a = 0; r = 0; b = 1; d = 1; s = 1;
    #10 b = 0; c = 1; d = 0; s = 0; r = 1;
    #10 c = 0; r = 0; s = 1;
    #10;
    foreach (reports[i])
      if (reports[i] != 1)
        $fatal(1, "case %0d reported %0d verdicts", i, reports[i]);
    foreach (events[i])
      if (events[i] != 4 || event_ticks[i] !== 64'h154)
        $fatal(1, "event case %0d count=%0d ticks=%h", i, events[i], event_ticks[i]);
    $display("PASSED");
    $finish(0);
  end
endmodule

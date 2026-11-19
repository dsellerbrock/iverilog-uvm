module issue3851_grouped_concat;
  bit clk;
  localparam int NAMED_DELAY = 3;
  int tick = 0;
  int hits[16];

  always #5 clk = !clk;
  always @(negedge clk) tick++;

  task automatic hit(input int test_id, expected_tick);
    if (tick != expected_tick || hits[test_id] != 0)
      $fatal(1, "case %0d at tick %0d, expected one hit at %0d",
             test_id, tick, expected_tick);
    hits[test_id]++;
  endtask

  // AND ends with its later operand. The ##3 starts at that endpoint.
  cover sequence (@(posedge clk)
    (tick == 0) ##1 (tick == 1)
    ##1 ((tick == 2) and ((tick == 2) ##1 (tick == 3)))
    ##3 (tick == 6)) hit(0, 6);

  // The short OR match at tick 1 cannot continue at tick 2.
  cover sequence (@(posedge clk)
    (tick == 0) ##1 ((tick == 1) or ((tick == 1) ##1 (tick == 2)))
    ##1 (tick == 3)) hit(1, 3);

  cover sequence (@(posedge clk)
    (tick == 0) ##0 ((tick == 0) intersect (tick == 0))
    ##1 (tick == 1)) hit(2, 1);

  // Two grouped operands, a grouped completed concatenation and
  // successive continuations.
  cover sequence (@(posedge clk)
    (((tick == 0) and (tick == 0)) ##0 ((tick == 0) or (tick == 8)))
    ##1 (tick == 1) ##1 (tick == 2)) hit(3, 2);

  sequence named_concat;
    ((tick == 0) ##1 ((tick == 1) and (tick == 1))) ##NAMED_DELAY (tick == 4);
  endsequence : named_concat

  cover sequence (@(posedge clk) named_concat) hit(4, 4);
  cover sequence (@(posedge clk) named_concat) hit(5, 4);

  assert property (@(posedge clk)
    ((tick == 0) ##1 ((tick == 1) and (tick == 1))) |=>
    (tick == 2) ##0 ((tick == 2) or (tick == 8)) ##1 (tick == 3))
    hit(6, 3); else $fatal(1, "tree-to-tree implication failed");

  // Both INTERSECT operands can match at either length. In this trace
  // their endpoints differ, so even a true suffix cannot complete it.
  assert property (@(posedge clk)
    (tick == 0) |-> (tick == 0) ##1
    (((tick == 1) ##[1:2] (tick == 2)) intersect
     ((tick == 1) ##[1:2] (tick == 3))) ##1 (tick == 4))
    else hit(7, 3);
  cover sequence (@(posedge clk)
    (tick == 0) ##1
    (((tick == 1) ##[1:2] (tick == 2)) intersect
     ((tick == 1) ##[1:2] (tick == 3))) ##1 (tick == 4))
    $fatal(1, "INTERSECT reached its suffix at tick %0d", tick);

  // Empty alternatives on each side of a positive boundary.
  cover sequence (@(posedge clk)
    (((1'b1[*0]) intersect (1'b1[*0])) or (tick == 8))
    ##3 (tick == 2)) hit(8, 2);
  cover sequence (@(posedge clk)
    (tick == 0) ##3 ((1'b1[*0]) or (tick == 8))
    ##1 (tick == 3)) hit(9, 3);

  // Dead concatenations are legal OR alternatives. ##0 excludes empty
  // matches on either side. ##1 cannot revive incompatible INTERSECT lengths.
  cover sequence (@(posedge clk)
    ((((1'b1[*0]) or (1'b1[*0])) ##0 (tick == 4)) or
     ((tick == 2) ##0 ((1'b1[*0]) or (1'b1[*0]))) or
     ((1'b1 intersect (1'b1 ##1 1'b1)) ##1 (tick == 5)) or (tick == 0)))
    hit(10, 0);

  // The right pair intersects at length 2, then AND ends at length 3.
  cover sequence (@(posedge clk)
    (tick == 0) or
    (tick == 0) ##1 ((tick == 1) or (tick == 8)) ##1 (tick == 2)
    and ((tick == 0) ##[1:2] (tick >= 1))
    intersect ((tick == 0) ##1 (tick == 1)))
    if (tick == 0) hit(11, 0); else hit(12, 2);

  // Empty ##1 empty supplies a nonoverlapped obligation at its start tick.
  assert property (@(posedge clk)
    (((1'b1[*0]) or (1'b1[*0])) ##1 (1'b1[*0])) |=> (tick == 3))
    hit(13, 3); else ;

  // Existing flat suffixes can contain a range or adjacent delays.
  cover sequence (@(posedge clk)
    ((tick == 0) and (tick == 0)) ##1 (tick == 1) ##[1:2] (tick == 3))
    hit(14, 3);
  cover sequence (@(posedge clk)
    ((tick == 0) and (tick == 0)) ##1 ##2 (tick == 3)) hit(15, 3);

  initial begin
    $assertvacuousoff(0);
    repeat (7) @(negedge clk);
    foreach (hits[i])
      if (hits[i] != 1) $fatal(1, "case %0d did not report a verdict", i);
    $display("PASSED");
    $finish(0);
  end
endmodule

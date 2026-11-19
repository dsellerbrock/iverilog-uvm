module issue3767_multiclock;
  bit root, clk1, clk2, abort_attempt;
  bit a, inherited_value;
  bit start = 1;
  int outcomes[9];

  property both;
    (@(posedge clk1) a) and (@(posedge clk2) 1'b1);
  endproperty

  property neither;
    (@(posedge clk1) 1'b0) or (@(posedge clk2) 1'b0);
  endproperty

  task automatic record(input int index, input time expected);
    if ($time != expected)
      $fatal(1, "outcome %0d at %0t, expected %0t", index, $time, expected);
    outcomes[index]++;
  endtask

  initial $assertvacuousoff(0);

  assert property (@(posedge root) start |=> both)
    record(0, 9);
  else $fatal(1, "named conjunction failed at %0t", $time);

  assert property (@(posedge root) start |=> neither)
    $fatal(1, "named disjunction passed at %0t", $time);
  else record(1, 9);

  assert property (@(posedge root) start |=>
                   (@(posedge clk1) a) or (@(posedge clk2) 1'b1))
    record(2, 5);
  else $fatal(1, "inline disjunction failed at %0t", $time);

  assert property (@(posedge root) start |=>
                   (@(posedge clk1) 1'b0) and (@(posedge clk2) 1'b1))
    $fatal(1, "inline conjunction passed at %0t", $time);
  else record(3, 5);

  assert property (@(posedge root) start |=>
                   (@(posedge clk2) 1'b1) or inherited_value)
    record(4, 7);
  else $fatal(1, "disjunction with inherited clock failed at %0t", $time);

  assert property (@(posedge root) start ##1 1'b1 |=>
                   (@(posedge clk1) 1'b1) or (@(posedge clk2) 1'b1))
    record(5, 9);
  else $fatal(1, "disjunction after a two-tick antecedent failed at %0t", $time);

  // A failed leaf is nonvacuous and is already settled when the other
  // branch succeeds vacuously. The disjunction must still run its action.
  assert property (@(posedge root) start |=>
                   (@(posedge clk1) 1'b0) or (@(posedge clk2) 1'b0 |-> 1'b1))
    record(6, 9);
  else $fatal(1, "settled disjunction failed at %0t", $time);

  // A still-pending leaf does not make the early vacuous pass nonvacuous.
  assert property (@(posedge root) start |=>
                   (@(posedge clk1) 1'b0 |-> 1'b1) or (@(posedge clk2) 1'b1))
    $fatal(1, "vacuous disjunction ran its pass action at %0t", $time);
  else $fatal(1, "vacuous disjunction failed at %0t", $time);

  assert property (@(posedge root) (start and 1'b1) |=>
                   ((@(posedge clk2) 1'b1) and (@(posedge clk2) 1'b1)))
    record(8, 9);
  else $fatal(1, "same-clock grouped conjunction failed at %0t", $time);

  initial begin
    // The first attempt is canceled while its second branch is pending.
    // A new attempt at the same assertion must still complete.
    repeat (2) begin
      assert property (@(posedge root) disable iff (abort_attempt) 1'b1 |=> both)
        record(7, 14);
      else $fatal(1, "conjunction with disable iff failed at %0t", $time);
      #10;
    end
  end

  initial begin
    // The coincident clk1 edge samples a=0 and must be skipped.
    #2 {root, clk1} = 2'b11;
    #1 {root, clk1} = 2'b00;
    start = 0;
    a = 1;
    inherited_value = 1;
    #2 clk1 = 1;
    #1 begin
      clk1 = 0;
      abort_attempt = 1;
    end
    // A second coincident edge at the longer antecedent's endpoint.
    #1 {root, clk1} = 2'b11;
    #1 abort_attempt = 0;
    #1 clk2 = 1;
    #1 {root, clk1, clk2} = 3'b000;
    #1 root = 1;
    #1 clk1 = 1;
    #2 clk2 = 1;
    #1;
    foreach (outcomes[i])
      if (outcomes[i] != 1)
        $fatal(1, "outcome %0d occurred %0d times", i, outcomes[i]);
    $display("PASSED");
    $finish;
  end
endmodule

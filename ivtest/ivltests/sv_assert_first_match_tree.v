module sv_assert_first_match_tree;
  bit clk = 0;
  always #5 clk = ~clk;

  bit pulse = 1, overlap_start = 1;
  bit at15, at25, at35, at45;
  logic early_gate = 1'bx;
  int early_fail, named_fail, param_pass, param_fail, or_pass, and_pass, isolated;
  int fused_hit, fused_miss, empty_first_fail, empty_late_fail, empty_and_pass;

  assert property (@(posedge clk)
    first_match((pulse ##1 1'b1) or (pulse ##2 1'b1)) |-> at15)
    or_pass++;
    else $fatal(1, "OR checked a later endpoint at %0t", $time);

  // Reuse a property carrying the grouped antecedent, with reversed polarity.
  property reverse_or;
    @(posedge clk)
      (first_match((pulse ##1 1'b1) or (pulse ##2 1'b1))) |-> !at15;
  endproperty
  assert property (reverse_or) else begin
    if ($time != 15) $fatal(1, "wrong early OR failure tick");
    early_fail++;
  end
  assert property (reverse_or) else begin
    if ($time != 15) $fatal(1, "wrong reused-property failure tick");
    named_fail++;
  end

  property delayed_or(bit req, bit ok);
    @(posedge clk) first_match((req ##1 1'b1) or (req ##2 1'b1)) |=> ok;
  endproperty
  assert property (delayed_or(pulse, at25))
    param_pass++;
    else $fatal(1, "wrong named nonoverlapped endpoint at %0t", $time);
  assert property (delayed_or(pulse, !at25)) else begin
    if ($time != 25) $fatal(1, "wrong parameterized failure tick");
    param_fail++;
  end

  // The ranged limb can end before, with, and after the fixed limb.
  assert property (@(posedge clk)
    first_match((pulse ##[1:3] 1'b1) and (pulse ##2 1'b1)) |-> at25)
    else $fatal(1, "wrong overlapped AND endpoint at %0t", $time);
  assert property (@(posedge clk)
    (first_match((pulse ##[1:3] 1'b1) and (pulse ##2 1'b1))) |=> at35)
    else $fatal(1, "wrong nonoverlapped AND endpoint at %0t", $time);
  assert property (@(posedge clk)
    first_match((pulse ##[1:3] 1'b1) and (pulse ##2 1'b1))
      |=> ((at35 ##0 1'b1) or (at35 ##1 1'b1)))
    and_pass++;
    else $fatal(1, "wrong tree consequent at %0t", $time);

  // At 15 the first slot accepts, but the newly injected slot must retain
  // its paths. Its early guard is X at 25, so it accepts at 45.
  assert property (@(posedge clk)
    first_match((overlap_start ##1 early_gate) or (overlap_start ##3 1'b1))
      |-> (at15 || at45))
    isolated++;
    else $fatal(1, "cut leaked between attempts at %0t", $time);

  // A fused suffix that fails at the first endpoint cannot retry at 25.
  cover property (@(posedge clk)
    (first_match((pulse ##1 1'b1) or (pulse ##2 1'b1))) ##0 at25)
    fused_miss++;
  cover property (@(posedge clk)
    (first_match((pulse ##1 1'b1) or (pulse ##2 1'b1))) ##0 at15)
    fused_hit++;

  // The empty match wins even when a nonempty OR limb could match later.
  assert property (@(posedge clk)
    first_match((overlap_start ##1 1'b1) or pulse[*0]) |=> !(pulse || at35))
    else begin
      if ($time == 5) empty_first_fail++;
      else if ($time == 35) empty_late_fail++;
      else $fatal(1, "wrong empty |=> endpoint at %0t", $time);
    end
  assert property (@(posedge clk)
    first_match(pulse[*0] and pulse[*0]) |=> 1'b1)
    empty_and_pass++;

  initial begin
    $assertvacuousoff(0);
    #10 pulse = 0; at15 = 1; early_gate = 1;
    #10 overlap_start = 0; at15 = 0; at25 = 1; early_gate = 1'bx;
    #10 at25 = 0; at35 = 1;
    #10 at35 = 0; at45 = 1;
    #10;
    if (early_fail != 1 || named_fail != 1 || param_pass != 1 ||
        param_fail != 1 || or_pass != 1 ||
        and_pass != 1 || isolated != 2 ||
        fused_miss != 0 || fused_hit != 1 ||
        empty_first_fail != 1 || empty_late_fail != 1 || empty_and_pass != 5)
      $fatal(1, "unexpected first_match verdict counts");
    $display("PASS");
    $finish(0);
  end
endmodule

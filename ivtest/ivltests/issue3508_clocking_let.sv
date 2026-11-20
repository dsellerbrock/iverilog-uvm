module issue3508_clocking_let;
  bit clk = 0;
  bit source;
  bit sampled_bit = 0;
  bit enabled = 1;
  bit request = 1, reply = 0;
  localparam int response_delay = 2;

  always #5 clk = ~clk;
  always @(posedge clk) source = ~source;

  let check(logic want) = 1'b0;
  let enabled_at_tick() = enabled && source;
  let external_arg = 1'b1;
  property pulse; @(negedge clk) 1'b0; endproperty

  clocking first @(posedge clk);
    input #1step sampled_bit = source;
    let pulse = sampled_bit;
    let want = 1'b1;
    (* test_attribute *) let check(logic want, logic value = pulse)
      = !want && value && enabled_at_tick();
    let previous = $past(sampled_bit);
    let external_arg = 1'b0;
    let response_delay = 1;
    sequence check_input; check(.want(2'b10)); endsequence
    sequence with_local; bit pulse = 1; pulse; endsequence
    property p; check_input; endproperty
    property history; previous; endproperty
    property with_formal(bit pulse); pulse; endproperty
    property timely; request |-> ##response_delay reply; endproperty
  endclocking

  clocking second @(posedge clk);
    input #1step sampled_bit = source;
    let pulse = !sampled_bit;
    property p; pulse; endproperty
  endclocking

  int first_passes, first_fails, repeat_passes, repeat_fails;
  int second_passes, second_fails, formal_passes, local_passes;
  int history_passes, history_fails;

  task automatic check_tick(input bit sampled_high);
    if ($time != 5 && $time != 15 && $time != 25)
      $fatal(1, "Unexpected assertion tick %0t", $time);
    if (sampled_high != ($time != 15))
      $fatal(1, "Wrong sampled result at %0t", $time);
  endtask

  assert property (first.p) begin
    check_tick(1);
    first_passes++;
  end else begin
    check_tick(0);
    first_fails++;
  end

  assert property (first.p) begin
    check_tick(1);
    repeat_passes++;
  end else begin
    check_tick(0);
    repeat_fails++;
  end

  assert property (second.p) begin
    check_tick(0);
    second_passes++;
  end else begin
    check_tick(1);
    second_fails++;
  end

  assert property (first.history) begin
    check_tick(0);
    history_passes++;
  end else begin
    check_tick(1);
    history_fails++;
  end

  assert property (first.with_formal(external_arg))
    formal_passes++;
  else $fatal(1, "Clocking let shadowed a property formal");

  assert property (first.with_local)
    local_passes++;
  else $fatal(1, "Clocking let shadowed a sequence local");

  assert property (first.timely)
  else $fatal(1, "Clocking let did not bind the cycle delay");

  initial begin
    if (check(1'b1) !== 1'b0)
      $fatal(1, "Clocking let escaped its block");
    #1 source = 1;
    #9 request = 0; reply = 1;
    #10 reply = 0;
    #6;
    if (first_passes != 2 || first_fails != 1 ||
        repeat_passes != 2 || repeat_fails != 1 ||
        second_passes != 1 || second_fails != 2 || formal_passes != 3 ||
        local_passes != 3 ||
        history_passes != 1 || history_fails != 2)
      $fatal(1, "Wrong pass and fail counts");
    $display("PASSED");
    $finish(0);
  end
endmodule

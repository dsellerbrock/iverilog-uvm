module issue3978_property_actual;
  bit clk, a, b, start, tail, inner_a, inner_b, stop;
  int pass_count[9], fail_count[9];
  always #5 clk = ~clk;

  task automatic verdict(input int id, input bit passed);
    time expected_tick;
    case (id)
      3: expected_tick = passed ? 25 : 55;
      8: expected_tick = passed ? 15 : 25;
      default: expected_tick = passed ? 5 : 15;
    endcase
    if ($time != expected_tick)
      $fatal(1, "assertion %0d pass=%b at %0t, expected %0t",
             id, passed, $time, expected_tick);
    if (passed) pass_count[id]++;
    else fail_count[id]++;
  endtask

  property pp(x);
    x;
  endproperty

  property typed(property x);
    if (1'b1) x;
  endproperty

  property with_default(x = (a |-> b));
    x;
  endproperty

  property stage(property x);
    tail |=> x;
  endproperty

  property route(x);
    start |=> stage(.x(x));
  endproperty

  property either_branch(property x);
    x or 1'b0;
  endproperty

  property folded(property x);
    x iff b;
  endproperty

  property next_tick(property x);
    a |-> nexttime x;
  endproperty

  untyped_actual: assert property (@(posedge clk) pp(a |-> b))
    verdict(0, 1); else verdict(0, 0);

  typed_actual: assert property (@(posedge clk) typed(.x(((a |-> b)))))
    verdict(1, 1); else verdict(1, 0);

  default_actual: assert property (@(posedge clk) with_default())
    verdict(2, 1); else verdict(2, 0);

  forwarded_actual: assert property (@(posedge clk) disable iff (stop)
                                     route(inner_a |-> inner_b))
    verdict(3, 1); else verdict(3, 0);

  iff_actual: assert property (@(posedge clk) if (a) pp(a iff b))
    verdict(4, 1); else verdict(4, 0);

  grouped_actual: assert property (@(posedge clk) if (a)
                                   pp(((a |-> b) and (a |-> b))))
    verdict(5, 1); else verdict(5, 0);

  or_operand: assert property (@(posedge clk) if (a) either_branch(a |-> b))
    verdict(6, 1); else verdict(6, 0);

  folded_operand: assert property (@(posedge clk) if (a) folded(a))
    verdict(7, 1); else verdict(7, 0);

  next_operand: assert property (@(posedge clk) next_tick(!b))
    verdict(8, 1); else verdict(8, 0);

  initial begin
    foreach (pass_count[i]) begin
      pass_count[i] = 0;
      fail_count[i] = 0;
    end
    $assertvacuousoff(0, untyped_actual, typed_actual, default_actual,
                     forwarded_actual, iff_actual, grouped_actual, or_operand,
                     folded_operand, next_operand);
    a = 1; b = 1; start = 1;
    #10 b = 0; start = 0; tail = 1;
    #10 a = 0; b = 1; tail = 0; inner_a = 1; inner_b = 1;
    #10 start = 1; inner_a = 0;
    #10 start = 0; tail = 1;
    #10 tail = 0; inner_a = 1; inner_b = 0;
    // The third outer match reaches an inner antecedent miss at 85.
    #10 start = 1; inner_a = 0;
    #10 start = 0; tail = 1;
    #10 tail = 0;
    // The fourth attempt is disabled between the tail and the inner check.
    #10 start = 1;
    #10 start = 0; tail = 1;
    #8 stop = 1; inner_a = 1;
    #4 stop = 0;
    #8;
    foreach (pass_count[i])
      if (pass_count[i] != 1 || fail_count[i] != 1)
        $fatal(1, "assertion %0d reported %0d passes and %0d fails",
               i, pass_count[i], fail_count[i]);
    $display("PASSED");
    $finish(0);
  end
endmodule

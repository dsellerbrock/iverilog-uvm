module issue3801;
  bit clk0, clk1, clk2;
  bit middle_ok, sequence_ok, property_ok, disable_instance;
  int results[4];
  bit passed[4];
  time result_at[4];

  sequence three_clocks;
    @(posedge clk0) 1'b1 ##1 @(posedge clk1) middle_ok
      ##1 @(posedge clk2) sequence_ok;
  endsequence

  property inline_implication;
    @(posedge clk0) 1'b1 ##1 @(posedge clk1) middle_ok
      |=> @(negedge clk2) property_ok;
  endproperty

  seq_a: assert property (three_clocks) record_result(0, 1);
    else record_result(0, 0);
  seq_b: assert property (three_clocks) record_result(1, 1);
    else record_result(1, 0);
  prop_a: assert property (inline_implication) record_result(2, 1);
    else record_result(2, 0);
  prop_b: assert property (disable iff (disable_instance) inline_implication)
      record_result(3, 1);
    else record_result(3, 0);

  task automatic record_result(input int index, input bit pass);
    results[index]++;
    passed[index] = pass;
    result_at[index] = $time;
  endtask

  task automatic check_result(input string label_name, input int index,
                              input int count, input bit pass, input time at);
    if (results[index] !== count || passed[index] !== pass || result_at[index] !== at)
      $fatal(1, "%s got count=%0d pass=%0b time=%0t, expected %0d %0b %0t",
             label_name, results[index], passed[index], result_at[index],
             count, pass, at);
  endtask

  task automatic trial(input bit success, input bit abort_one);
    sequence_ok = success;
    property_ok = success;
    #5 clk0 = 1;
    #1 clk0 = 0;
    middle_ok = 1;
    #4 clk1 = 1;
    #1 clk1 = 0;
    middle_ok = 0;
    // The disable pulse ends before either assertion reaches clk2.
    #1 disable_instance = abort_one;
    #2 disable_instance = 0;
    #1 clk2 = 1;
    #1 clk2 = 0;
    #4;
  endtask

  initial begin
    foreach (results[index]) results[index] = 0;

    trial(1, 0);
    check_result("seq_a",  0, 1, 1, 15);
    check_result("seq_b",  1, 1, 1, 15);
    check_result("prop_a", 2, 1, 1, 16);
    check_result("prop_b", 3, 1, 1, 16);

    // The disable pulse aborts prop_b in flight and leaves prop_a live.
    trial(0, 1);
    check_result("seq_a",  0, 2, 0, 35);
    check_result("seq_b",  1, 2, 0, 35);
    check_result("prop_a", 2, 2, 0, 36);
    check_result("prop_b", 3, 1, 1, 16);

    trial(1, 0);
    check_result("seq_a",  0, 3, 1, 55);
    check_result("seq_b",  1, 3, 1, 55);
    check_result("prop_a", 2, 3, 1, 56);
    check_result("prop_b", 3, 2, 1, 56);

    $display("PASSED");
    $finish(0);
  end
endmodule

module test;
  int ascending[0:2];
  int dynamic_values[];
  int queued_values[$];
  int result;

  task automatic inspect_fixed(input int values[2:0], output int encoded);
    encoded = values[2] * 100 + values[1] * 10 + values[0];
  endtask

  task automatic sum_open(input int values[], output int total);
    total = 0;
    foreach (values[i])
      total += values[i];
  endtask

  initial begin
    ascending = '{1, 2, 3};
    inspect_fixed(ascending, result);
    if (result != 123)
      $fatal(1, "fixed array formal did not map differing bounds left-to-right");

    sum_open(ascending, result);
    if (result != 6)
      $fatal(1, "fixed array actual did not match unsized formal");

    dynamic_values = new[3];
    dynamic_values = '{1, 2, 3};
    sum_open(dynamic_values, result);
    if (result != 6)
      $fatal(1, "dynamic array actual did not match unsized formal");

    queued_values = '{1, 2, 3};
    sum_open(queued_values, result);
    if (result != 6)
      $fatal(1, "queue actual did not match unsized formal");

    $display("PASS §7.7 array arguments");
    $finish;
  end
endmodule

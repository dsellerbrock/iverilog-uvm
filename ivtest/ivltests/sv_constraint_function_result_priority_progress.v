function automatic int count_ones(bit [9:0] value);
  for (count_ones = 0; value != 0; value = value >> 1)
    count_ones += value & 1'b1;
endfunction

class C;
  rand bit [9:0] value;
  rand bit [3:0] length;
  constraint c {
    length == count_ones(value);
    length < 3;
  }
endclass

module test;
  C item;
  int successes;
  int failed_check;
  bit [9:0] previous_value;
  bit [3:0] previous_length;

  initial begin
    for (int seed = 1; seed <= 3; seed++) begin
      item = new;
      item.srandom(seed);
      successes = 0;
      for (int i = 0; i < 200; i++) begin
        previous_value = item.value;
        previous_length = item.length;
        if (item.randomize()) begin
          successes++;
          if (item.length != count_ones(item.value) || item.length >= 3)
            $fatal(1, "invalid result for seed %0d", seed);
        end else if (item.value !== previous_value
                     || item.length !== previous_length)
          $fatal(1, "failed call changed fields for seed %0d", seed);
      end
      if (successes < 2 || successes > 30)
        failed_check = 1;
    end
    if (failed_check)
      $fatal(1, "success count outside expected range");
    $display("PASSED");
  end
endmodule

function automatic int count_ones(bit [9:0] value);
  for (count_ones = 0; value != 0; value = value >> 1)
    count_ones += value & 1'b1;
endfunction

class function_result_restriction;
  rand bit [9:0] value;
  rand bit [3:0] length;
  constraint result_and_limit { length == count_ones(value); length < 3; }
endclass

module test;
  function_result_restriction item;
  int successes;
  bit [9:0] previous_value;
  bit [3:0] previous_length;
  initial begin
    item = new;
    successes = 0;
    repeat (200) begin
      previous_value = item.value;
      previous_length = item.length;
      if (item.randomize()) begin
        successes++;
        if (item.length != count_ones(item.value) || item.length >= 3)
          $fatal(1, "invalid function-result sample");
      end else if (item.value !== previous_value
                   || item.length !== previous_length) begin
        $fatal(1, "failed randomize changed the object");
      end
    end
    if (successes == 0) $fatal(1, "all function-result randomizations failed");
    $display("PASSED");
  end
endmodule

class real_random;
  rand real value;
  rand bit lower_half;

  constraint range_c {
    value inside {[0.0:2.0]};
    value > 0.0;
    value < 2.0;
    lower_half == (value < 1.0);
  }

  constraint order_c { solve value before lower_half; }
endclass

module test;
  real_random item;
  int lower_count;
  real previous_value;
  bit previous_mode;

  initial begin
    item = new;
    item.srandom(32'd20261007);

    repeat (2048) begin
      if (!item.randomize())
        $fatal(1, "bounded real randomization failed");
      if (!(item.value > 0.0 && item.value < 2.0)
          || item.lower_half !== (item.value < 1.0))
        $fatal(1, "real constraint mismatch value=%0.16g lower=%0d",
               item.value, item.lower_half);
      if (item.value < 1.0)
        lower_count++;
    end

    if (lower_count < 896 || lower_count > 1152)
      $fatal(1, "equal real intervals were not equally likely: %0d/2048",
             lower_count);

    item.value = 0.5;
    item.lower_half = 1'b1;
    previous_value = item.value;
    previous_mode = item.lower_half;
    if (item.randomize() with { value < 0.0; })
      $fatal(1, "contradictory real constraints unexpectedly solved");
    if (item.value != previous_value || item.lower_half !== previous_mode)
      $fatal(1, "failed real randomization changed object state");

    $display("PASSED real lower-half=%0d/2048", lower_count);
  end
endmodule

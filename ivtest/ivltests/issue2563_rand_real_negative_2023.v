class negative_real_interval;
  rand real value;
  constraint range_c { value >= -3.0; value <= -2.0; }
endclass

class crossing_real_interval;
  rand real value;
  constraint range_c { value >= -1.0; value <= 1.0; }
endclass

module test;
  initial begin
    negative_real_interval negative;
    crossing_real_interval crossing;
    int i;

    negative = new;
    crossing = new;
    repeat (20) begin
      if (!negative.randomize())
        $fatal(1, "negative finite real interval did not randomize");
      if (negative.value < -3.0 || negative.value > -2.0)
        $fatal(1, "negative real value outside interval: %0.17g",
               negative.value);
      if (!crossing.randomize())
        $fatal(1, "zero-crossing finite real interval did not randomize");
      if (crossing.value < -1.0 || crossing.value > 1.0)
        $fatal(1, "zero-crossing real value outside interval: %0.17g",
               crossing.value);
      i++;
    end

    $display("PASSED negative and zero-crossing real intervals: %0d", i);
  end
endmodule

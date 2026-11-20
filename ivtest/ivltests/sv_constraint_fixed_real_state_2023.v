class fixed_real_state;
  real a[-2:0];
  int idx;
  bit [63:0] threshold = 2;

  constraint selected {
    if (idx inside {[-2:0]})
      a[idx] inside {[1.25:1.75]};
  }
  constraint constant_index { a[-2] inside {[1:2]}; }
  constraint real_guard { if (a[0]) a[idx] > 0; }
  // The IEEE binary64 bits of 1.5 are an integer here.
  constraint integral_bits { 64'h3ff8000000000000 > threshold; }
endclass

module test;
  fixed_real_state obj;
  initial begin
    obj = new;
    obj.a[-2] = 1.5;
    obj.a[-1] = 2.25;
    // A real negative zero is false even though its sign bit is set.
    obj.a[0] = $bitstoreal(64'h8000000000000000);
    if ($realtobits(obj.a[0]) != 64'h8000000000000000)
      $fatal(1, "Test requires stored negative zero");
    obj.idx = -2;
    if (!obj.randomize(null)) $fatal(1, "Selected 1.5 must pass");
    obj.idx = -1;
    if (obj.randomize(null)) $fatal(1, "Selected 2.25 must fail");
    obj.a[-1] = 1.75;
    if (!obj.randomize(null)) $fatal(1, "Selected upper endpoint must pass");
    obj.a[-1] = 1.7500000000000002;
    if (obj.randomize(null)) $fatal(1, "Value one binary64 step above the endpoint must fail");
    obj.idx = -3;
    if (!obj.randomize(null)) $fatal(1, "Guard must skip invalid index");
    obj.a[-2] = 2.25;
    if (obj.randomize(null)) $fatal(1, "Constant index must see updated 2.25");
    $display("PASSED");
  end
endmodule

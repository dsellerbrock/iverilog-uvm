class large_boundary_item;
  rand bit [9:0] value;
  constraint distribution_c {
    value dist {[0:300] :/ 1, [500:499] :/ 0, 700 :/ 0};
  }
  constraint exclusion_c { value inside {[100:200]}; }
endclass

class small_control_item;
  rand bit [7:0] value;
  constraint distribution_c { value dist {[3:17] :/ 1, 200 :/ 1}; }
endclass

class unsat_large_item;
  rand bit [9:0] value;
  constraint distribution_c { value dist {[0:300] :/ 1}; }
  constraint impossible_c { value > 400; }
endclass

class narrow_wide_item;
  rand bit [7:0] value;
  constraint distribution_c { value dist {[0:1000] :/ 1}; }
endclass

class signed_narrow_wide_item;
  rand bit signed [7:0] value;
  constraint distribution_c { value dist {[-1000:1000] :/ 1}; }
endclass

module test;
  large_boundary_item large_item;
  small_control_item small_item;
  unsat_large_item unsat;
  narrow_wide_item narrow;
  signed_narrow_wide_item signed_narrow;
  bit saw_unsigned_high, saw_signed_negative, saw_signed_positive;
  initial begin
    large_item = new; small_item = new;
    unsat = new; narrow = new; signed_narrow = new;
    narrow.srandom(32'h1000_0255);
    signed_narrow.srandom(32'h1000_5128);
    repeat (64) begin
      if (!large_item.randomize()
          || large_item.value < 100 || large_item.value > 200)
        $fatal(1, "large exclusion/zero/empty failure");
      if (!small_item.randomize()
          || !((small_item.value >= 3 && small_item.value <= 17)
               || small_item.value == 200))
        $fatal(1, "subcap control failure");
      if (!narrow.randomize()) $fatal(1, "narrow/wide randomize failed");
      if (narrow.value > 200) saw_unsigned_high = 1;
      if (!signed_narrow.randomize())
        $fatal(1, "signed narrow/wide randomize failed");
      if (signed_narrow.value < 0) saw_signed_negative = 1;
      else saw_signed_positive = 1;
    end
    if (!saw_unsigned_high || !saw_signed_negative || !saw_signed_positive)
      $fatal(1, "representable-image sampling incomplete");
    if (unsat.randomize()) $fatal(1, "UNSAT large distribution succeeded");
    $display("PASSED");
  end
endmodule

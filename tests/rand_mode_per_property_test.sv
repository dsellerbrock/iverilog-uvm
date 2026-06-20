// Regression: per-property rand_mode(0) (IEEE 1800-2017 §18.8).
//
// obj.prop.rand_mode(0) / prop.rand_mode(0) marks ONE property inactive (a
// state constant), leaving other rand members random.  iverilog silently
// DROPPED the per-property form at elaboration (only whole-object
// obj.rand_mode() was handled), so num_trans.rand_mode(0) in OpenTitan was a
// no-op and num_trans kept re-randomizing every iteration.
//
// Fix: elaborate obj.prop.rand_mode(en) -> $ivl_class_method$rand_mode with a
// property-index arg -> %rand_mode/p <pid>, which sets rand_mode for only that
// property.  Verifies BOTH the explicit-receiver and implicit-this forms, and
// that an unrelated rand var still randomizes.
module top;
  class C;
    rand int a;
    rand int b;
    rand int cc;
    constraint a_c  { a  inside {[5:10]}; }
    constraint b_c  { b  inside {[5:10]}; }
    constraint cc_c { cc inside {[1:3]};  }

    function int run_implicit();   // this.a.rand_mode(0)
      int bad = 0;
      a.rand_mode(0);
      a = 7;
      for (int i = 0; i < 20; i++) begin
        void'(this.randomize());
        if (a != 7) bad++;             // inactive: must stay 7
        if (cc < 1 || cc > 3) bad++;   // active: must stay in range
      end
      return bad;
    endfunction
  endclass

  initial begin
    C c = new();
    int errors = 0;
    // implicit-this form (the OpenTitan num_trans.rand_mode(0) pattern)
    errors += c.run_implicit();
    // explicit-receiver form
    c.b.rand_mode(0);
    c.b = 8;
    for (int i = 0; i < 20; i++) begin
      void'(c.randomize());
      if (c.b != 8) errors++;          // inactive: must stay 8
      if (c.a != 7) errors++;          // still inactive from run_implicit
    end
    if (errors == 0) $display("PASS");
    else $display("rand_mode_per_property_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule

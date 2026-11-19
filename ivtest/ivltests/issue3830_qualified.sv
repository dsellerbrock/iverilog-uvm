class issue3830_base;
  rand bit a;
  constraint base_value { a == 1; }

  function bit base_a();
    return a;
  endfunction
endclass

class issue3830_derived extends issue3830_base;
  rand bit a, b, c;
  constraint order_c {
    solve super.a before b;
    solve b before a;
    solve this.a before c;
  }
  constraint derived_values { a == 0; b == 1; c == 1; }
endclass

module top;
  issue3830_derived obj = new;

  initial begin
    obj.a = 1;
    if (!obj.randomize() || obj.base_a() != 1 || obj.a != 0
        || obj.b != 1 || obj.c != 1)
      $fatal(1, "qualified ordering failed");

    // An inactive rand property is still a legal solve-before operand.
    obj.a.rand_mode(0);
    obj.b = 0;
    if (!obj.randomize() || obj.base_a() != 1 || obj.a != 0
        || obj.b != 1 || obj.c != 1)
      $fatal(1, "qualified ordering failed with rand_mode(0)");
    $display("PASS");
  end
endmodule

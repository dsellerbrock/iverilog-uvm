class real_inside_scalar;
  rand real r;
  constraint c { r inside {1.0, 2.0, 3.0}; }
endclass

class real_inside_pair;
  rand real a, b;
  constraint c { a inside {1.0, 2.0}; b inside {1.0, 2.0}; a != b; }
endclass

class real_inside_triple;
  rand real a, b, c;
  constraint c_unique {
    a inside {1.0, 2.0, 3.0};
    b inside {1.0, 2.0, 3.0};
    c inside {1.0, 2.0, 3.0};
    a != b; a != c; b != c;
  }
endclass

module test;
  real_inside_scalar scalar;
  real_inside_pair pair;
  real_inside_triple triple;
  integer i;
  initial begin
    scalar = new;
    pair = new;
    triple = new;
    repeat (100) begin
      if (!scalar.randomize()) $fatal(1, "scalar real inside failed");
      if (scalar.r != 1.0 && scalar.r != 2.0 && scalar.r != 3.0)
        $fatal(1, "scalar real outside set: %0.17g", scalar.r);
      if (!pair.randomize()) $fatal(1, "pair real inside failed");
      if (!((pair.a == 1.0 && pair.b == 2.0)
            || (pair.a == 2.0 && pair.b == 1.0)))
        $fatal(1, "pair real values not distinct set members");
      if (!triple.randomize()) $fatal(1, "triple real inside failed");
      if (!((triple.a != triple.b) && (triple.a != triple.c)
            && (triple.b != triple.c)
            && (triple.a >= 1.0 && triple.a <= 3.0)
            && (triple.b >= 1.0 && triple.b <= 3.0)
            && (triple.c >= 1.0 && triple.c <= 3.0)))
        $fatal(1, "triple real values are not a permutation");
    end
    $display("PASSED: scalar and unique rand real inside points");
  end
endmodule

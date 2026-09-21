module test;
  int x = 123;
  int ok;
  process self;
  string rng;
  initial begin
    self = process::self();
    rng = self.get_randstate();
    ok = std::randomize(x) with { x == 7; };
    $display("RESULT ok=%0d x=%0d", ok, x);
    if ($test$plusargs("expect_unknown")) begin
      if (ok != 0 || x != 123) $fatal(1, "UNKNOWN must fail without changing x");
      if (self.get_randstate() != rng) $fatal(1, "UNKNOWN changed process RNG");
    end else if (ok != 1 || x != 7) $fatal(1, "SAT must satisfy constraint");
    $display("PASSED");
  end
endmodule

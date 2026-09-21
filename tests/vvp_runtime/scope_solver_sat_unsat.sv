module test;
  int x = 123; int ok; process self; string rng;
  initial begin
    self = process::self(); rng = self.get_randstate();
    ok = std::randomize(x) with { x == 7; };
    if (ok != 1 || x != 7) $fatal(1, "SAT failed");
    self.set_randstate(rng); x = 123;
    ok = std::randomize(x) with { x == 8; x == 9; };
    if (ok != 0 || x != 123 || self.get_randstate() != rng)
      $fatal(1, "UNSAT value/RNG rollback failed");
    $display("PASSED SAT UNSAT");
  end
endmodule

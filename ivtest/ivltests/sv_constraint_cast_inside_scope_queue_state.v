module sv_constraint_cast_inside_scope_queue_state;
  logic [7:0] known_values[$];
  logic [7:0] x_values[$];
  logic [7:0] z_values[$];
  bit [7:0] value;
  bit enable;
  int ok;
  process self;
  string rng;

  initial begin
    known_values.push_back(8'h2a);
    x_values.push_back('x);
    z_values.push_back('z);
    self = process::self();

    ok = std::randomize(value) with {
      int'(value inside {known_values}) == 1;
    };
    if (ok != 1 || value !== 8'h2a)
      $fatal(1, "known scope container value failed");

    value = 8'h94;
    self.srandom(32'h53515831);
    rng = self.get_randstate();
    ok = std::randomize(value) with {
      int'(value inside {x_values}) == 1;
    };
    if (ok != 0 || value !== 8'h94 || self.get_randstate() != rng)
      $fatal(1, "scope X container read did not fail and roll back");

    value = 8'h95;
    self.srandom(32'h53515a32);
    rng = self.get_randstate();
    ok = std::randomize(value) with {
      int'(value inside {z_values}) == 1;
    };
    if (ok != 0 || value !== 8'h95 || self.get_randstate() != rng)
      $fatal(1, "scope Z container read did not fail and roll back");

    enable = 1;
    value = 8'h96;
    ok = std::randomize(enable, value) with {
      enable == 0;
      if (enable) int'(value inside {x_values}) == 1;
      value == 8'h35;
    };
    if (ok != 1 || enable !== 0 || value !== 8'h35)
      $fatal(1, "inactive scope X guard was not sifted");

    $display("PASSED");
    $finish(0);
  end
endmodule

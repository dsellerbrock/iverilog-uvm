module sv_constraint_inside_scope_queue_state;
  logic [7:0] known_values[$];
  logic [7:0] x_values[$];
  logic [7:0] z_values[$];
  bit [7:0] value;
  bit enable;
  process self;
  string rng;
  int ok;

  initial begin
    known_values.push_back(8'h2a);
    x_values.push_back('x);
    z_values.push_back('z);
    self = process::self();

    ok = std::randomize(value) with { value inside {known_values}; };
    if (ok != 1 || value !== 8'h2a)
      $fatal(1, "known noncast scope container value failed");

    value = 8'ha3;
    self.srandom(32'h53505831);
    rng = self.get_randstate();
    ok = std::randomize(value) with { value inside {x_values}; };
    if (ok != 0 || value !== 8'ha3 || self.get_randstate() != rng)
      $fatal(1, "noncast scope X read did not roll back");

    value = 8'ha4;
    self.srandom(32'h53505a32);
    rng = self.get_randstate();
    ok = std::randomize(value) with { value inside {z_values}; };
    if (ok != 0 || value !== 8'ha4 || self.get_randstate() != rng)
      $fatal(1, "noncast scope Z read did not roll back");

    enable = 1;
    value = 8'ha5;
    ok = std::randomize(enable, value) with {
      enable == 0;
      if (enable) value inside {x_values};
      value == 8'h35;
    };
    if (ok != 1 || enable !== 0 || value !== 8'h35)
      $fatal(1, "inactive noncast scope read was not sifted");
    $display("PASSED");
    $finish(0);
  end
endmodule

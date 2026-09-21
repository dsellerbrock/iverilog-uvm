// IEEE 1800-2017/2023 18.3: a four-state value used by a constraint is an
// evaluation error.  Wrapping the read in an integral cast must preserve the
// focused diagnostic and transactional failure.
class cast_x_item;
  rand bit value;
  logic [7:0] state_value;
  int posts;

  function new();
    value = 1;
    state_value = 'x;
  endfunction
  function void post_randomize(); posts++; endfunction

  constraint c {
    int'(state_value) == 0;
    value == 0;
  }
endclass

module main;
  cast_x_item item = new;
  string rng;
  initial begin
    item.srandom(32'h58434153);
    rng = item.get_randstate();
    if (item.randomize())
      $fatal(1, "cast hid four-state constraint value");
    if (item.value != 1 || item.state_value !== 8'hxx || item.posts != 0)
      $fatal(1, "failed cast evaluation changed object state");
    if (item.get_randstate() != rng)
      $fatal(1, "failed cast evaluation changed RNG state");
    $display("PASSED");
  end
endmodule

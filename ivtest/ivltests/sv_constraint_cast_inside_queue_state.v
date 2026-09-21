class inside_queue_known;
  rand bit [7:0] value;
  logic [7:0] values[$];
  function new(); values.push_back(8'h2a); endfunction
  constraint c { int'(value inside {values}) == 1; }
endclass

class inside_queue_x;
  rand bit [7:0] value;
  logic [7:0] values[$];
  int posts;
  function new(); values.push_back('x); endfunction
  function void post_randomize(); posts++; endfunction
  constraint c { int'(value inside {values}) == 1; }
endclass

class inside_queue_z;
  rand bit [7:0] value;
  logic [7:0] values[$];
  int posts;
  function new(); values.push_back('z); endfunction
  function void post_randomize(); posts++; endfunction
  constraint c { int'(value inside {values}) == 1; }
endclass

class inside_queue_inactive_guard;
  rand bit enable;
  rand bit [7:0] value;
  logic [7:0] values[$];
  function new(); values.push_back('x); endfunction
  constraint c {
    enable == 0;
    if (enable) int'(value inside {values}) == 1;
    value == 8'h35;
  }
endclass

class inside_queue_active_guard;
  rand bit enable;
  rand bit [7:0] value;
  logic [7:0] values[$];
  int posts;
  function new(); values.push_back('x); endfunction
  function void post_randomize(); posts++; endfunction
  constraint c {
    enable == 1;
    if (enable) int'(value inside {values}) == 1;
  }
endclass

module sv_constraint_cast_inside_queue_state;
  inside_queue_known known;
  inside_queue_x active_x;
  inside_queue_z active_z;
  inside_queue_inactive_guard inactive;
  inside_queue_active_guard active_guard;
  int ok;
  string rng;

  initial begin
    known = new;
    active_x = new;
    active_z = new;
    inactive = new;
    active_guard = new;

    if (!known.randomize() || known.value !== 8'h2a)
      $fatal(1, "known four-state container value failed");

    active_x.value = 8'h91;
    active_x.srandom(32'h51555831);
    rng = active_x.get_randstate();
    ok = active_x.randomize();
    if (ok != 0 || active_x.value !== 8'h91 || active_x.posts != 0 ||
        active_x.get_randstate() != rng)
      $fatal(1, "active X container read did not fail and roll back");

    active_z.value = 8'h92;
    active_z.srandom(32'h51555a32);
    rng = active_z.get_randstate();
    ok = active_z.randomize();
    if (ok != 0 || active_z.value !== 8'h92 || active_z.posts != 0 ||
        active_z.get_randstate() != rng)
      $fatal(1, "active Z container read did not fail and roll back");

    if (!inactive.randomize() || inactive.enable !== 0 ||
        inactive.value !== 8'h35)
      $fatal(1, "inactive guarded X container read was not sifted");

    active_guard.enable = 0;
    active_guard.value = 8'h93;
    active_guard.srandom(32'h51475533);
    rng = active_guard.get_randstate();
    ok = active_guard.randomize();
    if (ok != 0 || active_guard.enable !== 0 ||
        active_guard.value !== 8'h93 || active_guard.posts != 0 ||
        active_guard.get_randstate() != rng)
      $fatal(1, "active guarded X read did not fail and roll back");

    $display("PASSED");
    $finish(0);
  end
endmodule

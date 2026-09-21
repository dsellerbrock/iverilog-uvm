class inside_queue_plain_known;
  rand bit [7:0] value;
  logic [7:0] values[$];
  function new(); values.push_back(8'h2a); endfunction
  constraint c { value inside {values}; }
endclass

class inside_queue_plain_bad;
  rand bit [7:0] value;
  logic [7:0] values[$];
  int posts;
  function new(bit use_z);
    values.push_back(use_z ? 8'hzz : 8'hxx);
  endfunction
  function void post_randomize(); posts++; endfunction
  constraint c { value inside {values}; }
endclass

class inside_queue_plain_inactive;
  rand bit enable;
  rand bit [7:0] value;
  logic [7:0] values[$];
  function new(); values.push_back('x); endfunction
  constraint c {
    enable == 0;
    if (enable) value inside {values};
    value == 8'h35;
  }
endclass

module sv_constraint_inside_queue_state;
  inside_queue_plain_known known;
  inside_queue_plain_bad active_x;
  inside_queue_plain_bad active_z;
  inside_queue_plain_inactive inactive;
  string rng;
  int ok;

  initial begin
    known = new;
    active_x = new(0);
    active_z = new(1);
    inactive = new;
    if (!known.randomize() || known.value !== 8'h2a)
      $fatal(1, "known noncast container value failed");

    active_x.value = 8'ha1;
    active_x.srandom(32'h504c5831);
    rng = active_x.get_randstate();
    ok = active_x.randomize();
    if (ok != 0 || active_x.value !== 8'ha1 || active_x.posts != 0 ||
        active_x.get_randstate() != rng)
      $fatal(1, "noncast X read did not roll back");

    active_z.value = 8'ha2;
    active_z.srandom(32'h504c5a32);
    rng = active_z.get_randstate();
    ok = active_z.randomize();
    if (ok != 0 || active_z.value !== 8'ha2 || active_z.posts != 0 ||
        active_z.get_randstate() != rng)
      $fatal(1, "noncast Z read did not roll back");

    if (!inactive.randomize() || inactive.enable !== 0 ||
        inactive.value !== 8'h35)
      $fatal(1, "inactive noncast container read was not sifted");
    $display("PASSED");
    $finish(0);
  end
endmodule

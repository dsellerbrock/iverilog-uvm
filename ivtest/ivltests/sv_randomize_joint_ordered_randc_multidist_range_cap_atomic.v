class cap_leaf;
  rand bit [7:0] value;
endclass

class cap_item;
  randc bit cycle;
  rand bit early;
  rand bit [14:0] first;
  rand bit second;
  rand cap_leaf child;
  int posts;

  function new;
    child = new;
  endfunction

  function void post_randomize;
    posts++;
  endfunction

  constraint order_c { solve early before first; }
  constraint relation_c {
    early == cycle;
    first == cycle;
    second == cycle;
    child.value == second;
  }
  // This range exceeds the bounded coupled projection and must reject the
  // call before any draw. The 301-value case remains a positive control.
  constraint large_c { first dist {[0:20000] := 1}; }
  constraint mid_c { first dist {[0:300] := 1}; }
  constraint small_c { first dist {0 := 1, 1 := 1}; }
  constraint second_c { second dist {0 := 1, 1 := 1}; }
endclass

module test;
  cap_item subject = new;
  cap_item control = new;
  cap_item mid_control = new;
  string root_rng, child_rng;
  bit old_cycle, old_early, old_second;
  bit [14:0] old_first;
  bit [7:0] old_child;

  initial begin
    subject.cycle = 1; subject.early = 1; subject.first = 15'h7fff;
    subject.second = 1; subject.child.value = 8'hff;
    control.cycle = subject.cycle; control.early = subject.early;
    control.first = subject.first; control.second = subject.second;
    control.child.value = subject.child.value;
    subject.srandom(32'h52414e47); subject.child.srandom(32'h52414e43);
    control.srandom(32'h52414e47); control.child.srandom(32'h52414e43);

    subject.small_c.constraint_mode(0);
    subject.mid_c.constraint_mode(0);
    control.large_c.constraint_mode(0);
    control.mid_c.constraint_mode(0);
    old_cycle = subject.cycle; old_early = subject.early;
    old_first = subject.first; old_second = subject.second;
    old_child = subject.child.value;
    root_rng = subject.get_randstate();
    child_rng = subject.child.get_randstate();

    if (subject.randomize())
      $fatal(1, "over-cap distribution range succeeded");
    if (subject.cycle !== old_cycle || subject.early !== old_early
        || subject.first !== old_first || subject.second !== old_second
        || subject.child.value !== old_child || subject.posts != 0)
      $fatal(1, "range-cap failure changed values/callbacks");
    if (subject.get_randstate() != root_rng
        || subject.child.get_randstate() != child_rng)
      $fatal(1, "range-cap failure changed RNG");

    mid_control.large_c.constraint_mode(0);
    mid_control.small_c.constraint_mode(0);
    if (!mid_control.randomize() || mid_control.first > 300
        || mid_control.early != mid_control.cycle
        || mid_control.first != mid_control.cycle
        || mid_control.second != mid_control.cycle
        || mid_control.child.value != mid_control.second
        || mid_control.posts != 1)
      $fatal(1, "301-value ordered multi-dist control failed");

    subject.large_c.constraint_mode(0);
    subject.small_c.constraint_mode(1);
    repeat (4) begin
      if (!subject.randomize() || !control.randomize())
        $fatal(1, "post-cap replay solve failed");
      if (subject.cycle != control.cycle || subject.early != control.early
          || subject.first != control.first || subject.second != control.second
          || subject.child.value != control.child.value
          || subject.posts != control.posts)
        $fatal(1, "range-cap failure consumed RNG or randc history");
    end
    $display("PASSED");
  end
endmodule

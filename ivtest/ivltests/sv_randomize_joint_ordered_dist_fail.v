class joint_ordered_dist_fail_leaf;
  rand bit value;
endclass
class joint_ordered_dist_multiple;
  rand bit a, b;
  rand joint_ordered_dist_fail_leaf child;
  int posts;
  bit impossible;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve a before b; }
  constraint a_dist { a dist {0 := 1, 1 := 2}; }
  constraint b_dist { b dist {0 := 1, 1 := 2}; }
  constraint coupled {
    child.value == b;
    a == b;
    if (impossible) { a == 0; a == 1; }
  }
endclass
module sv_randomize_joint_ordered_dist_fail;
  joint_ordered_dist_multiple multiple = new;
  string root_state, child_state;
  bit old_a, old_b, old_child;
  int old_posts;
  initial begin
    multiple.srandom(32'h85fa11);
    multiple.child.srandom(32'h85c11d);
    if (!multiple.randomize() || multiple.a != multiple.b ||
        multiple.child.value != multiple.b || multiple.posts != 1)
      $fatal(1, "multiple coupled dists did not solve jointly");
    old_a=multiple.a; old_b=multiple.b; old_child=multiple.child.value;
    old_posts=multiple.posts;
    root_state=multiple.get_randstate();
    child_state=multiple.child.get_randstate();
    multiple.impossible=1;
    if (multiple.randomize()) $fatal(1, "ordered contradiction succeeded");
    if (multiple.a !== old_a || multiple.b !== old_b
        || multiple.child.value !== old_child || multiple.posts != old_posts
        || multiple.get_randstate()!=root_state
        || multiple.child.get_randstate()!=child_state)
      $fatal(1, "ordered failure did not roll back atomically");
    $display("PASSED");
  end
endmodule

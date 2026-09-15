class joint_ordered_dist_fail_leaf;
  rand bit value;
endclass
class joint_ordered_dist_multiple;
  rand bit a, b;
  rand joint_ordered_dist_fail_leaf child;
  int posts;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve a before b; }
  constraint a_dist { a dist {0 := 1, 1 := 2}; }
  constraint b_dist { b dist {0 := 1, 1 := 2}; }
  constraint coupled { child.value == b; a == b; }
endclass
module sv_randomize_joint_ordered_dist_fail;
  joint_ordered_dist_multiple multiple = new;
  string root_state, child_state;
  initial begin
    multiple.srandom(32'h85fa11);
    multiple.child.srandom(32'h85c11d);
    root_state=multiple.get_randstate();
    child_state=multiple.child.get_randstate();
    if (multiple.randomize() || multiple.a || multiple.b ||
        multiple.child.value || multiple.posts ||
        multiple.get_randstate()!=root_state ||
        multiple.child.get_randstate()!=child_state)
      $fatal(1, "multiple coupled dists accepted or changed state");
    $display("PASSED");
  end
endmodule

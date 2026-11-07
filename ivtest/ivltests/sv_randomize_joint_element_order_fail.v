class joint_element_fail_leaf; rand bit value; endclass
class joint_element_cycle;
  rand bit values[2];
  rand joint_element_fail_leaf child;
  int posts;
  function new; child=new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c {
    solve values[0] before values[1];
    solve values[1] before values[0];
  }
  constraint coupled { child.value == values[1]; }
endclass
class joint_element_cap;
  rand bit values[11];
  rand joint_element_fail_leaf child;
  int posts;
  function new; child=new; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve values[0] before values[1]; }
  constraint coupled {
    child.value == (values[0]^values[1]^values[2]^values[3]^values[4]^
                    values[5]^values[6]^values[7]^values[8]^values[9]^
                    values[10]);
  }
endclass
module sv_randomize_joint_element_order_fail;
  joint_element_cycle cycle=new;
  joint_element_cap cap=new;
  string cycle_state,cycle_child_state,cap_state,cap_child_state;
  bit cap_changed;
  initial begin
    cycle.srandom(32'h87fa11); cycle.child.srandom(32'h87fc11);
    cap.srandom(32'h87fa12); cap.child.srandom(32'h87fc12);
    cycle_state=cycle.get_randstate(); cycle_child_state=cycle.child.get_randstate();
    cap_state=cap.get_randstate(); cap_child_state=cap.child.get_randstate();
    if (cycle.randomize() || cycle.values[0] || cycle.values[1] ||
        cycle.child.value || cycle.posts || cycle.get_randstate()!=cycle_state ||
        cycle.child.get_randstate()!=cycle_child_state)
      $fatal(1,"element cycle changed state");
    // The cyclic solve-before above must still fail (18.5.9: circular
    // dependencies are not allowed). The cap case has 2048 legal tuples,
    // past the solver's 1024-tuple enumeration cap.
    // IEEE 1800-2023 18.5.9: "a solve...before... constraint does not change the solution
    // space and, therefore, cannot cause the solver to fail" (#2228).
    if (!cap.randomize()) $fatal(1,"element cap failed");
    foreach (cap.values[i]) cap_changed ^= cap.values[i];
    if (cap.child.value != cap_changed || cap.posts != 1)
      $fatal(1,"element cap solution");
    $display("PASSED");
  end
endmodule

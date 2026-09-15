class joint_ordered_dist_tx_leaf;
  rand bit value;
endclass
class joint_ordered_dist_tx;
  rand bit a;
  rand bit [1:0] data;
  rand joint_ordered_dist_tx_leaf child;
  int posts;
  function new; child = new; endfunction
  function void post_randomize; posts++; endfunction
  constraint weights { a dist {0 := 1, 1 := 3}; }
  constraint order_c { solve a before data; }
  constraint fiber { if (!a) data == 0; child.value == data[0]; }
endclass
module sv_randomize_joint_ordered_dist_transaction;
  joint_ordered_dist_tx trial = new, control = new;
  bit ca0, ca1; bit [1:0] cd0, cd1;
  string trial_state, child_state;
  initial begin
    trial.srandom(32'h85f00d); control.srandom(32'h85f00d);
    if (!control.randomize()) $fatal(1, "control first");
    ca0=control.a; cd0=control.data;
    if (!control.randomize()) $fatal(1, "control second");
    ca1=control.a; cd1=control.data;
    if (!trial.randomize() || trial.a!=ca0 || trial.data!=cd0 || trial.posts!=1)
      $fatal(1, "replay first");
    trial_state=trial.get_randstate();
    child_state=trial.child.get_randstate();
    if (trial.randomize() with { a == 0; data == 3; } || trial.posts!=1 ||
        trial.a!=ca0 || trial.data!=cd0 || trial.child.value!=cd0[0] ||
        trial.get_randstate()!=trial_state ||
        trial.child.get_randstate()!=child_state)
      $fatal(1, "failed call changed transaction");
    if (!trial.randomize() || trial.a!=ca1 || trial.data!=cd1 || trial.posts!=2)
      $fatal(1, "failed call consumed draw");
    $display("PASSED");
  end
endmodule

// Unlike a one-shot compound @ expression, wait(expr) re-evaluates its full
// condition after every contributing class-property mutation.
class compound_wait_state;
  bit left;
  bit right;
  int wake_count;

  task wait_both;
    wait (left && right);
    wake_count++;
  endtask
endclass

module sv_class_property_compound_wait;
  compound_wait_state state;

  initial begin
    state = new;
    fork
      state.wait_both();
    join_none

    #1;
    state.left = 1;
    #1;
    if (state.wake_count != 0)
      $fatal(1, "wait condition did not re-evaluate");

    state.right = 1;
    #1;
    if (state.wake_count != 1)
      $fatal(1, "compound class-property wait did not complete");

    $display("PASSED");
  end
endmodule

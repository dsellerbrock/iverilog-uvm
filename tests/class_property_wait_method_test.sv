// IEEE 1800-2017 9.4.3: a wait expression is re-evaluated whenever an
// operand changes.  This specifically covers a class property observed from
// an automatic method while another method mutates the same object.
class wait_state;
  bit in_reset = 1'b1;
  bit released;

  task wait_for_release();
    wait (!in_reset);
    released = 1'b1;
  endtask

  function void release_reset();
    in_reset = 1'b0;
  endfunction
endclass

class wait_owner;
  wait_state cfg;
  bit nested_released;
  bit root_ready;
  bit multi_released;

  function new(wait_state cfg);
    this.cfg = cfg;
  endfunction

  task wait_for_nested_release();
    wait (!cfg.in_reset);
    nested_released = 1'b1;
  endtask

  task wait_for_root_and_nested_release();
    wait (root_ready && !cfg.in_reset);
    multi_released = 1'b1;
  endtask

  function void release_root();
    root_ready = 1'b1;
  endfunction
endclass

module class_property_wait_method_test;
  wait_state state;
  wait_state nested_state;
  wait_state multi_state;
  wait_owner owner;
  wait_owner multi_owner;

  initial begin
    state = new;
    nested_state = new;
    multi_state = new;
    owner = new(nested_state);
    multi_owner = new(multi_state);
    fork
      state.wait_for_release();
      owner.wait_for_nested_release();
      multi_owner.wait_for_root_and_nested_release();
    join_none

    #1;
    state.release_reset();
    nested_state.release_reset();
    // Wake the multi-object wait on its nested operand first while the root
    // operand is still false. It must then subscribe to both dependencies so
    // the later root mutation wakes it again.
    multi_state.release_reset();
    #1;
    multi_owner.release_root();
    #1;

    if (state.released !== 1'b1) begin
      $display("FAILED: wait(!in_reset) did not wake after method mutation");
      $finish_and_return(1);
    end
    if (owner.nested_released !== 1'b1) begin
      $display("FAILED: wait(!cfg.in_reset) did not wake after nested mutation");
      $finish_and_return(1);
    end
    if (multi_owner.multi_released !== 1'b1) begin
      $display("FAILED: multi-object class-property wait missed root mutation");
      $finish_and_return(1);
    end

    $display("PASSED: direct, nested, and multi-object class-property waits woke");
    $finish;
  end
endmodule

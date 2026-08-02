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

  function new(wait_state cfg);
    this.cfg = cfg;
  endfunction

  task wait_for_nested_release();
    wait (!cfg.in_reset);
    nested_released = 1'b1;
  endtask
endclass

module class_property_wait_method_test;
  wait_state state;
  wait_state nested_state;
  wait_owner owner;

  initial begin
    state = new;
    nested_state = new;
    owner = new(nested_state);
    fork
      state.wait_for_release();
      owner.wait_for_nested_release();
    join_none

    #1;
    state.release_reset();
    nested_state.release_reset();
    #1;

    if (state.released !== 1'b1) begin
      $display("FAILED: wait(!in_reset) did not wake after method mutation");
      $finish_and_return(1);
    end
    if (owner.nested_released !== 1'b1) begin
      $display("FAILED: wait(!cfg.in_reset) did not wake after nested mutation");
      $finish_and_return(1);
    end

    $display("PASSED: direct and nested class-property waits woke after mutation");
    $finish;
  end
endmodule

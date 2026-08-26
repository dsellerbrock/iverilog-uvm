// A method call can read additional properties of the same receiver. The
// wait sensitivity must therefore retain delivery sensitivity for `this';
// the explicit-field mutation dependency alone is not complete.
class class_property_wait_method_state;
  bit explicit_field;
  bit hidden_field;
  bit woke;

  function bit predicate();
    return hidden_field;
  endfunction

  task run();
    wait (explicit_field || predicate());
    woke = 1;
  endtask
endclass

module sv_class_property_wait_method_receiver;
  class_property_wait_method_state state;

  initial begin
    state = new;
    fork
      state.run();
    join_none
    #1;
    state.hidden_field = 1;
    #1;
    if (!state.woke) begin
      $display("FAILED: receiver mutation hidden behind method did not wake wait");
      $finish;
    end
    $display("PASSED");
  end
endmodule

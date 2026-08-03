class dynamic_hook_base;
  rand bit [7:0] data;
endclass

class dynamic_hook_derived extends dynamic_hook_base;
  bit post_called;
  bit parity;

  function void post_randomize();
    post_called = 1'b1;
    parity = ^data;
  endfunction
endclass

module randomize_dynamic_post_hook_test;
  dynamic_hook_base base_handle;
  dynamic_hook_base plain_base;
  dynamic_hook_derived derived;

  initial begin
    derived = new;
    base_handle = derived;
    if (!base_handle.randomize() with { base_handle.data == 8'h2a; }) begin
      $error("randomize through base handle failed");
      $finish_and_return(1);
    end
    if (!derived.post_called || derived.parity !== ^8'h2a) begin
      $error("dynamic post_randomize hook was skipped");
      $finish_and_return(1);
    end

    // The dynamic guard must not invoke the derived hook on a real base object.
    plain_base = new;
    if (!plain_base.randomize() with { plain_base.data == 8'h35; }) begin
      $error("base-object randomize failed");
      $finish_and_return(1);
    end

    $display("PASSED: dynamic post_randomize through base handle");
    $finish;
  end
endmodule

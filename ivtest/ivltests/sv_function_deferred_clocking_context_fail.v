// IEEE 1800-2017/2023 13.4.4: clocking drives from a function are deferred.
module sv_function_deferred_clocking_context_fail;
  logic clk = 0;
  logic target = 0;
  clocking cb @(posedge clk);
    output target;
  endclocking
  function integer schedule();
    cb.target <= 1;
    schedule = 1;
  endfunction
  wire unused = schedule();
  initial begin #1 clk = 1; #2; $display("UNEXPECTED"); $finish; end
endmodule

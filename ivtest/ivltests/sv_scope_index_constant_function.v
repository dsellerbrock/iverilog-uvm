// A static constant function is a legal constant instance-array selector.
// Scope-path evaluation must enable constant-function folding even when the
// global optimization is otherwise disabled.
module scope_index_leaf;
  logic value;
endmodule

module sv_scope_index_constant_function;
  scope_index_leaf cells [1:0] ();

  function integer selected_instance;
    selected_instance = 1;
  endfunction

  initial begin
    cells[0].value = 1'b0;
    cells[1].value = 1'b0;
    cells[selected_instance()].value = 1'b1;
    #1;
    if (cells[0].value !== 1'b0 || cells[1].value !== 1'b1)
      $fatal(1, "constant-function scope index selected the wrong instance");
    $display("PASSED");
  end
endmodule

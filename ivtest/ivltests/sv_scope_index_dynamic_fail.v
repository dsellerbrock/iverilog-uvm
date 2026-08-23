// A run-time variable cannot select an element of an instance array in a
// hierarchical name. Diagnose the invalid constant scope path without a
// compiler assertion or duplicate NEED_CONST diagnostic.
module scope_index_dynamic_leaf;
  logic value;
endmodule

module sv_scope_index_dynamic_fail;
  scope_index_dynamic_leaf cells [1:0] ();
  integer index;

  initial begin
    index = 0;
    $display("%b", cells[index].value);
  end
endmodule

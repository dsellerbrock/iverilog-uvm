// IEEE 1800-2017/2023 6.21: automatic locals are inaccessible hierarchically.
module sv_hier_automatic_local_fail;
  function automatic int transient();
    int count;
    return count;
  endfunction
  function int persistent_scope();
    automatic int value;
    return value;
  endfunction
  initial begin
    $display("%0d", transient.count);
    persistent_scope.value = 3;
  end
endmodule

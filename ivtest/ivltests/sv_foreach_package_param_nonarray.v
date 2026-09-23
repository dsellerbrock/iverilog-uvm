package foreach_param_nonarray_pkg;
  parameter int SCALAR = 7;
  class model;
    function new();
      foreach (SCALAR[i]) $display("unreachable %0d", i);
    endfunction
  endclass
endpackage
module main;
  foreach_param_nonarray_pkg::model obj;
  initial obj = new();
endmodule

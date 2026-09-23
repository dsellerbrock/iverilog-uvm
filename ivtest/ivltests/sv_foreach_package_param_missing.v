package foreach_param_missing_pkg;
  class model;
    function new();
      foreach (MISSING[i]) $display("unreachable %0d", i);
    endfunction
  endclass
endpackage
module main;
  foreach_param_missing_pkg::model obj;
  initial obj = new();
endmodule

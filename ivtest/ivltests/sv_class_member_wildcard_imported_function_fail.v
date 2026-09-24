package imported_pkg;
  function int foo(); return 7; endfunction
endpackage
package use_pkg;
  import imported_pkg::*;
  class C;
    int foo;
    function int value(); return foo(); endfunction
  endclass
endpackage
module top;
  use_pkg::C c;
  initial begin c = new; $display("INVALID %0d", c.value()); end
endmodule

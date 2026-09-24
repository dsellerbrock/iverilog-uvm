package p1; string path = "p1"; endpackage
package p2; string path = "p2"; endpackage
package P;
  class B;
    protected string path = "correct";
  endclass
endpackage
package use_pkg;
  import p1::*;
  import p2::*;
  class B;
    int other;
  endclass
  class C extends P::B;
    function string value(); return path; endfunction
  endclass
endpackage
module top;
  use_pkg::C c;
  initial begin c = new; if (c.value() != "correct") $fatal(1,"wrong base"); $display("PASS scoped base"); end
endmodule

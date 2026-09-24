package p1; string path = "p1"; endpackage
package p2; string path = "p2"; endpackage
package P;
  class B;
    local string path = "hidden";
  endclass
endpackage
package use_pkg;
  import p1::*;
  import p2::*;
  class B;
    protected string path = "wrong";
  endclass
  class C extends P::B;
    function string value(); return path; endfunction
  endclass
endpackage
module top;
  use_pkg::C c;
endmodule

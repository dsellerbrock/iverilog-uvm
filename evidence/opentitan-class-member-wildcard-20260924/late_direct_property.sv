package p1; string path="p1"; endpackage
package p2; string path="p2"; endpackage
package pkg;
  import p1::*;
  import p2::*;
  class C;
    function string get(); return path; endfunction
    string path = "member";
  endclass
endpackage
module top;
  pkg::C c;
  initial begin c = new; if (c.get() != "member") $fatal(1); $display("PASSED"); end
endmodule

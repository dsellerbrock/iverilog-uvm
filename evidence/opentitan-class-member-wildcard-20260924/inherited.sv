package p1; string path = "p1"; endpackage
package p2; string path = "p2"; endpackage
package pkg;
  import p1::*;
  import p2::*;
  class base;
    protected string path = "member";
  endclass
  class child extends base;
    function string value(); return path; endfunction
  endclass
endpackage
module top;
  pkg::child c;
  initial begin c = new; if (c.value() != "member") $fatal(1,"inherited member"); $display("PASS inherited"); end
endmodule

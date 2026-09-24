package otp_scrambler_pkg;
  string path = "otp";
endpackage
package sram_scrambler_pkg;
  string path = "sram";
endpackage
package mem_bkdr_util_pkg;
  import otp_scrambler_pkg::*;
  import sram_scrambler_pkg::*;
  class mem_bkdr_util;
    protected string path;
    function new(string value); path = value; endfunction
    function string convert2string();
      return $sformatf("path = %0s\n", path);
    endfunction
    function string explicit_member();
      return $sformatf("path = %0s\n", this.path);
    endfunction
  endclass
endpackage
package one_import_pkg;
  import otp_scrambler_pkg::*;
  class one_import_class;
    function string value(); return path; endfunction
  endclass
endpackage
module top;
  mem_bkdr_util_pkg::mem_bkdr_util m;
  one_import_pkg::one_import_class one;
  initial begin
    m = new("member");
    one = new;
    if (m.convert2string() != "path = member\n") $fatal(1, "bare member mismatch");
    if (m.explicit_member() != "path = member\n") $fatal(1, "explicit member mismatch");
    if (one.value() != "otp") $fatal(1, "one import mismatch");
    $display("PASSED");
  end
endmodule

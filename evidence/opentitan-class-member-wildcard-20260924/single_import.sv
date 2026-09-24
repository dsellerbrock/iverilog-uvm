package otp_scrambler_pkg;
  string path = "otp";
endpackage
package sram_scrambler_pkg;
  string path = "sram";
endpackage
package mem_bkdr_util_pkg;
  import otp_scrambler_pkg::*;
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
module top;
  mem_bkdr_util_pkg::mem_bkdr_util m;
  initial begin
    m = new("member");
    if (m.convert2string() != "path = member\n") $fatal(1, "bare member mismatch");
    if (m.explicit_member() != "path = member\n") $fatal(1, "explicit member mismatch");
    $display("PASS member");
  end
endmodule

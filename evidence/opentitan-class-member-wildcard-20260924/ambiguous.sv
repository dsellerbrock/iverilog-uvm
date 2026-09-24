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
    function string convert2string();
      return $sformatf("path = %0s\n", path);
    endfunction
  endclass
endpackage
module top;
  mem_bkdr_util_pkg::mem_bkdr_util m;
endmodule

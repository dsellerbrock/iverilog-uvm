// An always_comb's implicit sensitivity excludes arguments and locals of the
// functions it calls (IEEE 1800-2017/2023 9.2.2.2.1). A select of a string
// argument (UVM's uvm_re_match, reached from an assertion's uvm_error in
// OpenTitan entropy_src) survived the width-based removal and crashed the
// compiler on an out-of-range part select.
package rpt_pkg;
  function automatic bit re_match(string re, string str);
    if (re.len() > 1 && re[0] == "/" && re[re.len()-1] == "/")
      re = re.substr(1, re.len()-2);
    return re == str;
  endfunction
endpackage
module test;
  import rpt_pkg::*;
  logic a = 0, b = 0, y;
  int hits;
  always_comb begin
    y = a & b;
    if (re_match("/ab/", "ab")) hits++;
  end
  initial begin
    #1 a = 1; #1 b = 1; #1;
    if (y === 1'b1 && hits >= 1) $display("PASSED"); else $display("FAILED %b %0d", y, hits);
  end
endmodule

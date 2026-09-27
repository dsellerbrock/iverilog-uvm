// A method call on a package function's result is a statement (IEEE
// 1800-2017/2023 8.10), as in OpenTitan's
//   sec_cm_pkg::find_sec_cm_if_proxy(.path(p), .is_regex(1)).disable_fi();
package p;
  class proxy;
    int n;
    function void disable_fi(); n++; endfunction
  endclass
  proxy the = new;
  function automatic proxy find(string path, bit is_regex = 0);
    return the;
  endfunction
endpackage
module test;
  initial begin
    p::find("a").disable_fi();
    p::find(.path("b"), .is_regex(1)).disable_fi();
    void'(p::find("c"));
    if (p::the.n == 2) $display("PASSED"); else $display("FAILED");
  end
endmodule

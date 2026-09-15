module sv_const_mixed_equality_strings;
  function automatic int checked;
    string a = "a";
    string b = "a";
    string c = "aa";
    if (!(a == b) || a != b || a == c || !(a != c)) return 0;
    if (!("a" == 8'h61) || "a" != 16'h0061) return 0;
    if (!("ab" == 16'h6162) || !("ab" === 24'h006162)) return 0;
    if (!("a" == "\000a") || !(32'h61 === "\000a")) return 0;
    return 1;
  endfunction
  localparam int OK = checked();
  initial begin
    if (!OK || !checked()) $fatal(1, "string equality semantics changed");
    $display("PASSED");
  end
endmodule

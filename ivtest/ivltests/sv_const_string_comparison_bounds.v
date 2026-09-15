module sv_const_string_comparison_bounds;
  function automatic int cmp(input string left, input string right);
    return left.compare(right);
  endfunction
  function automatic int icmp(input string left, input string right);
    return left.icompare(right);
  endfunction

  localparam int EMPTY_EQUAL = cmp("", "");
  localparam int EMPTY_LESS = cmp("", "a");
  localparam int PREFIX_LESS = cmp("ab", "abc");
  localparam int PREFIX_GREATER = cmp("abc", "ab");
  localparam int HIGH_GREATER = cmp("\200", "\177");
  localparam int HIGH_LESS = cmp("\177", "\200");
  localparam int HIGH_CASELESS = icmp("A\200z", "a\200Z");
  localparam int HIGH_DISTINCT = icmp("\200", "\201");

  initial begin
    if (EMPTY_EQUAL != 0 || !(EMPTY_LESS < 0) || !(PREFIX_LESS < 0) ||
        !(PREFIX_GREATER > 0) || !(HIGH_GREATER > 0) || !(HIGH_LESS < 0) ||
        HIGH_CASELESS != 0 || !(HIGH_DISTINCT < 0))
      $fatal(1, "string comparison boundary mismatch");
    $display("PASSED");
  end
endmodule

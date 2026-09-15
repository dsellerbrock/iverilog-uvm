module sv_const_string_comparison;
  function automatic int compare_checked(input string left, input string right);
    string saved_left;
    string saved_right;
    int result;
    saved_left = left;
    saved_right = right;
    result = left.compare(right);
    if (left != saved_left || right != saved_right) return 32'sh80000000;
    return result;
  endfunction
  function automatic int icompare_checked(input string left, input string right);
    string saved_left;
    string saved_right;
    int result;
    saved_left = left;
    saved_right = right;
    result = left.icompare(right);
    if (left != saved_left || right != saved_right) return 32'sh80000000;
    return result;
  endfunction

  localparam int LESS = compare_checked("abc", "abd");
  localparam int EQUAL = compare_checked("same", "same");
  localparam int GREATER = compare_checked("abd", "abc");
  localparam int CASED = compare_checked("AbC", "aBc");
  localparam int CASELESS = icompare_checked("AbC", "aBc");
  localparam int REPEAT = icompare_checked("MiXeD", "mixed");

  initial begin
    string left;
    string right;
    int runtime_cmp;
    int runtime_icmp;
    left = "AbC";
    right = "aBc";
    runtime_cmp = left.compare(right);
    runtime_icmp = left.icompare(right);
    if (!(LESS < 0) || EQUAL != 0 || !(GREATER > 0) || !(CASED < 0) ||
        CASELESS != 0 || REPEAT != 0 ||
        ((runtime_cmp < 0) != (CASED < 0)) || runtime_icmp != 0 ||
        left != "AbC" || right != "aBc")
      $fatal(1, "constant/runtime string comparison mismatch");
    $display("PASSED");
  end
endmodule

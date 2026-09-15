module sv_const_array_string_character_incdec_recursive;
  function automatic string recurse(input int depth);
    string words[2];
    words[0] = "a";
    words[1] = "z";
    words[0][0]++;
    words[1][0]--;
    if (depth == 0) return {words[0], words[1]};
    return {words[0], words[1], recurse(depth-1)};
  endfunction
  localparam string VALUE = recurse(2);
  initial begin
    if (VALUE != "bybyby") $fatal(1, "recursive frame result %s", VALUE);
    $display("PASSED");
  end
endmodule

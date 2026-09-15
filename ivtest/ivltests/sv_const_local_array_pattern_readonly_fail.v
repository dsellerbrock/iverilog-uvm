module sv_const_local_array_pattern_readonly_fail;
  function automatic string folded;
    const string words[2] = '{"a", "b"};
    words[0] = "x";
    return words[0];
  endfunction
  localparam string VALUE = folded();
endmodule

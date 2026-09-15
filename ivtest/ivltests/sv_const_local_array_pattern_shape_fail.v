module sv_const_local_array_pattern_shape_fail;
  function automatic string folded;
    string words[2] = '{"a"};
    return words[0];
  endfunction
  localparam string VALUE = folded();
endmodule

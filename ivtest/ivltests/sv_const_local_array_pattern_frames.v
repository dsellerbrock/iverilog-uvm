module sv_const_local_array_pattern_frames;
  function automatic string recursive(input int depth);
    string words[2][2] = '{'{"a", "b"}, '{"c", "d"}};
    if (depth == 0) return {words[0][0], words[1][1]};
    words = '{default:"z"};
    return {recursive(depth-1), words[0][0], words[1][1]};
  endfunction
  localparam string VALUE = recursive(2);
  initial begin
    if (VALUE != "adzzzz" || recursive(2) != "adzzzz")
      $fatal(1, "nested array pattern frame mismatch");
    $display("PASSED");
  end
endmodule

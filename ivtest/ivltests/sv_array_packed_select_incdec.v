module sv_array_packed_select_incdec;
  logic [15:0] values[5:3];
  logic bit_result;
  logic [3:0] part_result;
  int word_calls, select_calls;

  function automatic int word_index(input int index);
    word_calls++;
    return index;
  endfunction
  function automatic int select_index(input int index);
    select_calls++;
    return index;
  endfunction

  initial begin
    values='{default:'0}; values[4]=16'ha55a;
    bit_result=++values[word_index(4)][select_index(2)];
    if (values[4]!==16'ha55e || bit_result!==1 || word_calls!=1 || select_calls!=1)
      $fatal(1,"bit prefix or selector evaluation");

    word_calls=0; select_calls=0;
    part_result=values[word_index(4)][select_index(4)+:4]++;
    if (values[4]!==16'ha56e || part_result!==4'h5 || word_calls!=1 || select_calls!=1)
      $fatal(1,"part postfix or selector evaluation");
    if (values[5]!=='0 || values[3]!=='0) $fatal(1,"neighbor word changed");
    $display("PASSED");
  end
endmodule

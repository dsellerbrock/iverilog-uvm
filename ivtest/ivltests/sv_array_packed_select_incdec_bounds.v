module sv_array_packed_select_incdec_bounds;
  logic [7:0] values[0:1];
  logic bit_result;
  logic [3:0] part_result;
  logic [127:0] word_index, packed_index;
  bit [7:0] two_state[0:1];
  bit two_bit_result;
  bit [3:0] two_part_result;
  logic [7:0] x_word, x_packed;
  int word_calls, packed_calls;

  function automatic int word_side(input int value); word_calls++; return value; endfunction
  function automatic int packed_side(input int value); packed_calls++; return value; endfunction

  initial begin
    values='{8'ha5,8'h5a}; part_result=values[99][3:0]++;
    if (values[0]!==8'ha5 || values[1]!==8'h5a || part_result!==4'hx)
      $fatal(1,"constant invalid word");

    word_index='0; word_index[100]=1; packed_index=0;
    bit_result=values[word_index][packed_index]++;
    if (values[0]!==8'ha5 || values[1]!==8'h5a || bit_result!==1'bx)
      $fatal(1,"wide word index truncated");

    word_index=0; packed_index='0; packed_index[100]=1;
    bit_result=values[word_index][packed_index]++;
    if (values[0]!==8'ha5 || values[1]!==8'h5a || bit_result!==1'bx)
      $fatal(1,"wide packed index truncated");

    values[0]=8'haa; part_result=values[0][6+:4]++;
    if (values[0]!==8'bxx101010 || part_result!==4'bxx10)
      $fatal(1,"partial OOB packed update");

    two_state='{8'ha5,8'h5a}; word_calls=0; packed_calls=0;
    two_part_result=two_state[word_side(9)][packed_side(0)+:4]++;
    if (two_state[0]!=8'ha5 || two_state[1]!=8'h5a || two_part_result!=0 ||
        word_calls!=1 || packed_calls!=1) $fatal(1,"two-state invalid word");
    two_state='{8'ha5,8'h5a}; x_word='x; packed_calls=0;
    two_part_result=++two_state[x_word][packed_side(0)+:4];
    if (two_state[0]!=8'ha5 || two_state[1]!=8'h5a || two_part_result!=1 ||
        packed_calls!=1) $fatal(1,"two-state unknown word");
    two_state='{8'haa,8'h5a}; x_packed='x; word_calls=0;
    two_bit_result=two_state[word_side(0)][x_packed]++;
    if (two_state[0]!=8'haa || two_state[1]!=8'h5a || two_bit_result!=0 ||
        word_calls!=1) $fatal(1,"two-state unknown packed bit");
    two_state='{8'haa,8'h5a}; word_calls=0;
    two_part_result=two_state[word_side(0)][6+:4]++;
    if (two_state[0]!=8'hea || two_state[1]!=8'h5a || two_part_result!=4'h2 ||
        word_calls!=1) $fatal(1,"two-state partial OOB part");
    $display("PASSED");
  end
endmodule

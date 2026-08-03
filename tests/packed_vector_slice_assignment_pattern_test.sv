module packed_vector_slice_assignment_pattern_test;
  logic [1:0][1:0][2:0][3:0] state;
  integer i;

  initial begin
    state = '0;
    i = 1;
    state[i][0] = '{default: '1};
    if (state[1][0] !== '1 || state[0][0] !== '0 || state[1][1] !== '0)
      $fatal(1, "packed-vector slice assignment pattern failed");
    $display("PASS: packed-vector slice assignment pattern");
  end
endmodule

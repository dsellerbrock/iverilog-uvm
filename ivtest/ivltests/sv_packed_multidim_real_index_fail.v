module sv_packed_multidim_real_index_fail;
  logic [1:0][3:0] words;
  real outer_index;
  integer inner_index;
  logic value;

  initial begin
    outer_index = 0.0;
    inner_index = 0;
    value = words[outer_index][inner_index];
  end
endmodule

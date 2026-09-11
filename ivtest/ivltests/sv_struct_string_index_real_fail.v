module sv_struct_string_index_real_fail;
  typedef struct { string val; } row_t;
  row_t row;
  real idx;
  initial begin
    row.val = "abc"; idx = 1.5;
    $display("%d", row.val[idx]);
  end
endmodule

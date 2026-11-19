module sv_uarray_runtime_slice_write_fail;
  int dest[0:3], source[0:1], one[0:0], driven[0:3];
  byte wrong_type[0:1];
  string strings[0:3];
  integer i, width;
  real real_index;
  typedef int pair_t[0:1];

  function automatic pair_t result();
    result[0] = 1;
    result[1] = 2;
  endfunction

  assign driven[3] = 1;
  initial begin
    dest[i +: width] = source;
    dest[i +: 2.0] = source;
    dest[real_index +: 2] = source;
    dest[i +: 2] = one;
    dest[i +: 2] <= wrong_type;
    dest[i +: 2] = '{1};
    dest[i +: 2] = #1 source;
    dest[i +: 2] <= #1 source;
    dest[i +: 2] = result();
    dest[i +: 2] <= result();
    dest[i +: 2] = '{0:1, default:2};
    strings[i +: 2] <= '{"a", "b"};
    driven[i +: 2] = source;
  end
endmodule

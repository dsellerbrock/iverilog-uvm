// IEEE 1800-2017 permits non-blocking assignment of an unpacked-array
// function result, but vvp does not yet have the required per-word NBA
// snapshot representation. Keep both whole-array and fixed-slice forms loud
// until they can be scheduled without degrading the aggregate to a vector.
module sv_uarray_func_return_nb_fail;
  typedef int row_t [0:1];

  function automatic row_t make_row();
    make_row[0] = 1;
    make_row[1] = 2;
  endfunction

  int whole [0:1];
  int sliced [0:1][0:1];

  initial begin
    whole <= make_row();
    sliced[1] <= make_row();
  end
endmodule

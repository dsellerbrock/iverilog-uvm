// A nonblocking unpacked-array assignment still requires an
// assignment-compatible function result (IEEE 1800-2017/2023 7.6).
module sv_uarray_func_return_nb_fail;
  typedef int two_t [0:1];
  typedef int three_t [0:2];

  function automatic three_t make_three();
    make_three[0] = 1;
    make_three[1] = 2;
    make_three[2] = 3;
  endfunction

  two_t target;

  initial target <= make_three();
endmodule

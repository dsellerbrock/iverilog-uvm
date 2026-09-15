// IEEE 1800-2017/2023 13.4.1: typed function-name return storage.
module sv_real_uarray_return_boundary;
  typedef real row_t[2:1];
  row_t first, second;

  function automatic row_t make_real(input real delta, input int which);
    make_real = '{2: 1.25, 1: 2.5};
    make_real[which] += delta;
    make_real[1] *= 2.0;
  endfunction

  initial begin
    first = make_real(3.0, 2);
    second = make_real(1.0, 2);
    if (first[2] != 4.25 || first[1] != 5.0
        || second[2] != 2.25 || second[1] != 5.0)
      $fatal(1, "real indexed/compound return writes");
    first[2] = 99.0;
    if (second[2] != 2.25)
      $fatal(1, "real return arrays alias across calls");
    $display("PASSED");
  end
endmodule

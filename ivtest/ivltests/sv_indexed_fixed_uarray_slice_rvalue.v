module sv_indexed_fixed_uarray_slice_rvalue;
  int source[0:3];
  int destination[1:2];
  int base;

  initial begin
    source[0] = 10;
    source[1] = 20;
    source[2] = 30;
    source[3] = 40;
    base = 1;
    destination = source[base +: 2];
    if (destination[1] !== 20 || destination[2] !== 30)
      $fatal(1, "ascending indexed unpacked slice");
    base = 2;
    destination = source[base -: 2];
    if (destination[1] !== 20 || destination[2] !== 30)
      $fatal(1, "descending indexed unpacked slice");
    $display("PASSED");
  end
endmodule

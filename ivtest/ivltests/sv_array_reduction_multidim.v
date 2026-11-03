// IEEE 1800-2017/2023 7.12.3: reduction over a multidimensional array.
module sv_array_reduction_multidim;
  logic [7:0] m [2][2] = '{ '{5, 10}, '{15, 20} };
  int y;

  initial begin
    y = m.sum with (item.sum with (item));
    if (y !== 50)
      $fatal(1, "nested multidimensional sum: got %0d, expected 50", y);
    $display("PASSED");
  end
endmodule

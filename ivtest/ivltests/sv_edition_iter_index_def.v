// Edition gate, defining-edition arm: `index' is legal in 1800-2023 and
// must still compute the right value there (0+1+2+3+4 = 10).
module sv_edition_iter_index_def;
  int arr[5] = '{5,1,2,3,4};
  int s;
  initial begin
    s = arr.sum with (item.index);
    if (s == 10) $display("PASSED");
    else $display("FAILED -- sum with (item.index) = %0d, expected 10", s);
  end
endmodule

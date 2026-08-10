// Edition boundary, defining-edition arm: iterator index querying was
// already present in IEEE 1800-2005 5.15.4 and must work under -g2005-sv
// (0+1+2+3+4 = 10).
module sv_edition_iter_index_def;
  int arr[5] = '{5,1,2,3,4};
  int s;
  initial begin
    s = arr.sum with (item.index);
    if (s == 10) $display("PASSED");
    else $display("FAILED -- sum with (item.index) = %0d, expected 10", s);
  end
endmodule

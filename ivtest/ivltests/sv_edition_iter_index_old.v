// Edition gate, older-mode arm: the `index' iterator property of an
// array manipulation method is IEEE 1800-2023 (7.12). Under -g2012 it
// used to bind silently and produce the numerically correct 2023
// answer (sum = 0+1+2+3+4 = 10) for a user who asked for 2012.
module sv_edition_iter_index_old;
  int arr[5] = '{5,1,2,3,4};
  int s;
  initial begin
    s = arr.sum with (item.index);
    $display("FAILED -- should not have compiled under -g2012 (got %0d)", s);
  end
endmodule

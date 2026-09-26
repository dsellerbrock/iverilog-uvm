// Every fixed selector must already name a visible value; an undeclared
// one would silently become a fresh loop variable (IEEE 1800-2017/2023
// 12.7.3), so it is an error in any position.
module test;
  int arr[2][3][4];
  initial begin
    int bank;
    foreach (arr[bank][typo][i]) arr[bank][typo][i] = i;
  end
endmodule

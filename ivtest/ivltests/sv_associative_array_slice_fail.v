// Associative arrays use keyed element selects, not positional array or
// queue slices (IEEE 1800-2017/2023 7.8-7.10).
module top;
  int data[int];
  int result[int];

  initial begin
    result = data[1:2];
    result = data[1 +: 2];
    result = data[2 -: 2];
  end
endmodule

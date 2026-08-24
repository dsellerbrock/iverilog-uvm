// A packed part select retains the constant-bound requirement even though
// queue slices use the same [first:last] syntax with runtime bounds.
module top;
  logic [31:0] value;
  logic [31:0] result;
  int upper;

  initial begin
    upper = 7;
    result = value[0:upper];
  end
endmodule

module top;
  string unit;
  string signed_result;
  string unsigned_result;
  string constant_result;
  integer signed_count;
  int unsigned unsigned_count;

  initial begin
    unit = "ab";
    signed_count = 2;
    unsigned_count = 3;
    signed_result = {signed_count{unit}};
    unsigned_result = {unsigned_count{unit}};
    constant_result = {2{unit}};
    $display("typed=<%s>|<%s>|<%s>", signed_result,
             unsigned_result, constant_result);
  end
endmodule

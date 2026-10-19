module top;
  reg signed [0:0] signed_one;
  reg signed [7:0] signed_byte;
  reg signed [30:0] signed_31;
  reg signed [31:0] signed_32;
  reg [32:0] unsigned_33;
  reg [3:0] unsigned_xz;
  reg signed [3:0] signed_xz;
  reg signed [3:0] signed_z_sign;
  reg unsigned_one;

  initial begin
    signed_one = 1'b1;
    signed_byte = 8'hfb;
    signed_31 = 31'h40000001;
    signed_32 = 32'h80000000;
    unsigned_33 = 33'h1_80000000;
    unsigned_xz = 4'b1x0z;
    signed_xz = 4'b1x0z;
    signed_z_sign = 4'bz001;
    unsigned_one = 1'b1;
    #1 $check_intval_values;
    $finish;
  end
endmodule

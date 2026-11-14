// Issue #2882: continuous assignments with a select on either side are
// cont assign objects (IEEE 1800-2023 37.47) with a vpiLhs and a vpiRhs
// whose vpiDecompile reads in the declared range (37.59 detail 2).
module top;
  logic [3:0] src;
  logic [0:7] asc;
  wire [1:0] o1;
  wire o2;
  wire [7:0] cat;
  wire [1:0] hi, lo;
  wire [2:0] o3;
  assign o1 = src[2:1];
  assign o2 = src[0];
  assign cat[3:0] = src;
  assign {hi, lo} = src;
  assign o3 = asc[1:3];
  initial begin
    src = 4'b0110;
    asc = 8'b0110_0000;
    #1 $probe;
  end
endmodule

// Issue #1277 (IEEE 1800-2023 37.16 details 14-15, 37.21): active forces
// and procedural assign statements are drivers and loads. $probe checks
// them from VPI after each step.
module top;
  wire scalar;
  wire [3:0] vec;
  reg r, q;
  assign scalar = 1'b0;
  assign vec = 4'b1010;
  initial begin
    force scalar = r;
    force vec[1:0] = 2'b11;
    assign q = r;
    #1 $probe(1);
    force scalar = q;
    #1 $probe(2);
    release scalar;
    deassign q;
    #1 $probe(3);
  end
endmodule

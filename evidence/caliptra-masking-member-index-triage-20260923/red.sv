// Reduced from pinned Adams Bridge v2.0.3 abr_masked_B2A_conv_tb.sv:139.
module top;
  typedef struct { logic [1:0] x [1:0]; } sample_t;
  sample_t sample;
  logic selected;
  initial begin
    sample.x[1] = 2'b10;
    selected = sample.x[1][1];
    if (selected !== 1'b1) $fatal(1, "mixed member indexing");
    $display("PASSED mixed member indexing");
  end
endmodule

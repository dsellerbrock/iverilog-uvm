// The same unpacked struct-member element without a trailing packed select.
module top;
  typedef struct { logic [1:0] x [1:0]; } sample_t;
  sample_t sample;
  logic [1:0] selected;
  initial begin
    sample.x[1] = 2'b10;
    selected = sample.x[1];
    if (selected !== 2'b10) $fatal(1, "whole element indexing");
    $display("PASSED whole element indexing");
  end
endmodule

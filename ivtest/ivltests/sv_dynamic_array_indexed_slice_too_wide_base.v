// A 128-bit base is legal syntax but beyond the current nonwrapping index
// carrier. Reject explicitly rather than truncating onto a valid element.
module test;
  logic data[];
  logic selected[];
  logic [127:0] base;
  initial begin
    base = 128'd1;
    selected = data[base +: 2];
    data[base +: 2] = selected;
  end
endmodule

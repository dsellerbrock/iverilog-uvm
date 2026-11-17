module main;
  bit [7:0] source[2];
  logic [7:0] four_state[$];
  bit signed [7:0] signed_value[$];
  bit [6:0] narrower[$];
  initial begin
    four_state = source[0:1];
    signed_value = source[0:1];
    narrower = source[0:1];
  end
endmodule

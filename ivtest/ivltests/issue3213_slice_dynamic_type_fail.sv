module main;
  logic signed [31:0] source[1:3];
  bit signed [31:0] two_state[];
  logic [31:0] unsigned_value[];
  initial begin
    two_state = source[1:2];
    unsigned_value = source[1:2];
  end
endmodule

module runtime_variable_width;
  logic [7:0] storage = 8'hac;
  int BlkLen = 4;
  wire [3:0] selected = storage[7 -: BlkLen];
endmodule

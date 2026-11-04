module tb;
  wire [1:0] w;
  assign (strong1,strong0) w = 2'b01;
  wire (strong1,strong0) [1:0] declared_vector = 2'b10;
endmodule

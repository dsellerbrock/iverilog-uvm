module top;
  wire scalared [3:0] bus;
  wire vectored [3:0] vec;
  wire [1:0][1:0] packed_bus;
  assign bus = 4'b0101;
  assign vec = bus;
  assign packed_bus = bus;
  initial begin
    #1;
    $check_expanded;
    $finish;
  end
endmodule

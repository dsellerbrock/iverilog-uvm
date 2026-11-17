module top;
  bit clk;
  localparam logic [1:0] X_INDEX = 2'b0x;
  for (genvar i = 0; i <  2; i++) begin : G
    A: assert property (@(posedge clk) 1'b1);
  end
  initial begin
    $assertoff(0, G[X_INDEX].A);
    $assertoff(0, G[1'bz].A);
  end
endmodule

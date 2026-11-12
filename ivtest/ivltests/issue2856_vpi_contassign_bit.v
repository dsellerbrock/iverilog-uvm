module top;
  logic [3:0] src;
  wire [3:0] out;
  assign out = src;
  initial begin
    src = 4'b0101;
    #1 $probe;
    #1 src = 4'b0111;
    #1 $done;
    #1 $finish;
  end
endmodule

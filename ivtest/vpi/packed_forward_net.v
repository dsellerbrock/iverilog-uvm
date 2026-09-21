module forward_net;
  logic [1:0][3:0] a = 8'h12;
  logic [1:0][3:0] b = 8'h21;
  wire  [1:0][3:0] sum = a + b;
  initial begin
    #1;
    if (sum !== 8'h33) $fatal(1, "forward net source control");
    $forward_net_check;
  end
endmodule

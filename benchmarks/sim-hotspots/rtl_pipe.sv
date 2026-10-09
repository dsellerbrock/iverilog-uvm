// RTL-style: many clocked processes, NBAs, continuous assigns, 32-bit arith.
module stage #(parameter K=1) (input clk, input rst, input [31:0] din, output reg [31:0] dout);
  wire [31:0] mixed = (din ^ (din << 5)) + K;
  always @(posedge clk) if (rst) dout <= 0; else dout <= mixed ^ (mixed >> 3);
endmodule
module top;
  localparam N = 128;
  reg clk = 0, rst = 1;
  wire [31:0] d [0:N];
  reg [31:0] lfsr = 32'h1;
  assign d[0] = lfsr;
  genvar i;
  generate for (i=0;i<N;i=i+1) begin : g
    stage #(.K(i)) s(.clk(clk), .rst(rst), .din(d[i]), .dout(d[i+1]));
  end endgenerate
  always #5 clk = ~clk;
  always @(posedge clk) lfsr <= {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
  reg [31:0] acc = 0;
  always @(posedge clk) if (rst) acc <= 0; else acc <= acc + d[N];
  initial begin
    #20 rst = 0;
    #100000;
    $display("acc=%h lfsr=%h", acc, lfsr);
    $finish;
  end
endmodule

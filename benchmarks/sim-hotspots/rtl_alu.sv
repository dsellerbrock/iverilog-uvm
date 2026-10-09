// Mixed RTL: continuous-assign ALU datapath + compare/shift/mux + FSM + memory.
module alu(input [31:0] a, b, input [2:0] op, output [31:0] y, output eq, lt, zero);
  wire [31:0] s = a + b, d = a - b, sl = a << b[4:0], sr = a >> b[4:0];
  wire [31:0] an = a & b, o = a | b, x = a ^ b;
  assign y = (op == 3'd0) ? s : (op == 3'd1) ? d : (op == 3'd2) ? sl :
             (op == 3'd3) ? sr : (op == 3'd4) ? an : (op == 3'd5) ? o : x;
  assign eq = (a == b);
  assign lt = (a < b);
  assign zero = (y == 32'd0);
endmodule
module lane #(parameter K=0) (input clk, input rst, input [31:0] seed);
  reg [31:0] ra, rb; reg [2:0] op; reg [7:0] cnt;
  wire [31:0] y; wire eq, lt, zero;
  reg [31:0] mem [0:15];
  reg [1:0] st;
  alu u(.a(ra), .b(rb), .op(op), .y(y), .eq(eq), .lt(lt), .zero(zero));
  always @(posedge clk) begin
    if (rst) begin ra <= seed; rb <= seed ^ K; op <= 0; cnt <= 0; st <= 0; end
    else begin
      case (st)
        2'd0: begin ra <= y ^ {24'd0, cnt}; st <= 2'd1; end
        2'd1: begin rb <= lt ? rb + 1 : rb - 3; st <= eq ? 2'd3 : 2'd2; end
        2'd2: begin mem[cnt[3:0]] <= y; st <= 2'd0; end
        default: begin ra <= mem[cnt[3:0]]; st <= 2'd0; end
      endcase
      op <= op + 1; cnt <= cnt + (zero ? 2 : 1);
    end
  end
endmodule
module top;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;
  genvar i;
  generate for (i=0;i<64;i=i+1) begin : g
    lane #(.K(i*7+1)) l(.clk(clk), .rst(rst), .seed(32'h1234567 * (i+1)));
  end endgenerate
  initial begin
    #20 rst = 0;
    #200000;
    $display("ra0=%h rb0=%h ra63=%h cnt5=%h", g[0].l.ra, g[0].l.rb, g[63].l.ra, g[5].l.cnt);
    $finish;
  end
endmodule

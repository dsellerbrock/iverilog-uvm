// Pinned clockhdr (beh_lib.sv:770-787), rvdff (beh_lib.sv:18-45), EL2_RAM body (mem_lib.sv, non-GTLSIM).
module clockhdr(input logic SE, EN, CK, output Q);
   logic en_ff; logic enable;
   assign enable = EN | SE;
   always @(CK, enable) begin if(!CK) en_ff = enable; end
   assign Q = CK & en_ff;
endmodule
module rvdff #(parameter WIDTH=1)(input logic [WIDTH-1:0] din, input logic clk, input logic rst_l, output logic [WIDTH-1:0] dout);
   always_ff @(posedge clk or negedge rst_l) begin
      if (rst_l == 0) dout[WIDTH-1:0] <= 0; else dout[WIDTH-1:0] <= din[WIDTH-1:0];
   end
endmodule
module ram(input logic [3:0] ADR, input logic [38:0] D, output logic [38:0] Q, input logic CLK, ME, WE);
   reg [38:0] ram_core [15:0];
   always @(posedge CLK) begin
      if (ME && WE) begin ram_core[ADR] <= D; Q <= 'x; end
      if (ME && ~WE) Q <= ram_core[ADR];
   end
endmodule
interface mif; logic clk; logic me, we; logic [38:0] q; endinterface
module t;
   logic clk = 0, rst_l = 0, c2r_en = 0, me = 0, we = 0, rd_m = 0;
   always #5 clk = ~clk;
   mif mi(); assign mi.clk = clk;
   wire active_clk, c2r_clk; logic r;
   clockhdr a(.SE(1'b0), .EN(1'b1), .CK(clk), .Q(active_clk));
   clockhdr b(.SE(1'b0), .EN(c2r_en), .CK(active_clk), .Q(c2r_clk));
   ram u(.ADR(4'd7), .D(39'h0), .Q(mi.q), .CLK(mi.clk), .ME(me), .WE(we));
   logic m; always_comb m = rd_m & ^mi.q;      // X iff a read's Q is unknown
   rvdff #(1) rf(.din(m), .clk(c2r_clk), .rst_l(rst_l), .dout(r));
   initial begin
      u.ram_core[7] = 39'h0;
      @(negedge clk) rst_l = 1;
      @(negedge clk) begin me = 1; we = 0; end            // read bank at next posedge
      @(negedge clk) begin rd_m = 1; c2r_en = 1; me = 1; we = 1; end // m-stage load; same bank written next edge
      @(negedge clk) begin rd_m = 0; me = 0; we = 0; end
      $display("r=%b (expected 0) q=%b", r, mi.q);
      $display(r === 1'b0 ? "RESULT GREEN" : "RESULT RED");
      $finish;
   end
endmodule

module top;
 generate if (1) begin : g wire x=1'b1; end endgenerate
 initial #1 $display("GR %b", g.x);
endmodule

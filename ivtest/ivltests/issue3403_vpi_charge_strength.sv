module charge_port(cap);
   inout [1:0] cap;
   trireg (small) [1:0] cap;
endmodule

module top;
   trireg (large) #(0,0,50) large_cap;
   trireg (small) [1:0] small_cap;
   trireg (medium) medium_cap;
   trireg default_cap;
   trireg (small) [2:1] cap_array [2:3];
   trireg (medium) [1:0][0:1] packed_cap;

   // Each VPI handle reports its declaration, even across a collapsed port.
   trireg (large) [1:0] outer_cap;
   charge_port u(outer_cap);
   wire [1:0] ordinary;
   charge_port v(ordinary);
endmodule

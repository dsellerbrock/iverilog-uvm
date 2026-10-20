module muxz_chain_delta;
  reg d0, d1, d2, s0, s1;
  wire y = s1 ? d2 : (s0 ? d1 : d0);
  initial begin d0=0; d1=1; d2=0; s0=0; s1=0; #1 s0=1; #1 $finish; end
  always @(s0) if (s0 === 1'b1) s1 = 1'b1;
  always @(y) $display("%0t y=%b", $time, y);
endmodule

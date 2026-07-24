module dff(input clk, d); specify $setup(d, posedge clk, 10); endspecify endmodule
module tb; reg c=0, d=0; dff u(c,d);
  initial begin #10 d=1; #1 c=1; #10 $display("PASS (ran; look for violation above)"); $finish(0); end
endmodule

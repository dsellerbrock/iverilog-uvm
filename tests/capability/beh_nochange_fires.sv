module m(input clk, d); specify $nochange(posedge clk, d, 0, 5); endspecify endmodule
module tb; reg c=0,d=0; m u(c,d);
  initial begin #10 c=1; #2 d=1; #10 $display("PASS (ran)"); $finish(0); end
endmodule

module top;
  trireg (small) t; reg d=1, en=1;
  assign t = en ? d : 1'bz;
  initial begin #1 en=0; #1 if (t===1'b1) $display("PASS"); else $display("FAIL t=%b",t); $finish(0); end
endmodule

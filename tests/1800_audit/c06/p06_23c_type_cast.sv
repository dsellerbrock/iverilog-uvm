module p06_23c;
  int i=5, e; logic [15:0] v=16'hABCD;
  initial begin e=type(i+3)'(v[15:0]); $display("CAST e=%0d",e); end
endmodule

module pm #(parameter P=5,Q=6);
  initial $display("P=%0d Q=%0d",P,Q);
endmodule

module tb;
  pm #(.P(1),.P(2)) u();
endmodule

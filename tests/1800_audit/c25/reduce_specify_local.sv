module dtype(input c,d, output q); reg qi; always @(posedge c) qi<=d; buf (q,qi); specify (posedge c => (q+:d))=(5,6); $setup(d,posedge c,1); endspecify endmodule
module top; reg c=0,d=1; wire q; dtype x(c,d,q); initial begin #2 c=1; #1 $display("Q %b",q); end endmodule

interface itf; logic c,q,d; modport flop(input c,d, output q); endinterface
module dtype(itf.flop ch);
 always_ff @(posedge ch.c) ch.q <= ch.d;
 specify ( posedge ch.c => (ch.q+:ch.d)) = (5,6); $setup(ch.d, posedge ch.c, 1); endspecify
endmodule
module top; itf i(); dtype d(i.flop);
 initial begin i.d = 1; #2 i.c = 1; #1 $display("SP3 %b", i.q); #5 $display("SP8 %b", i.q); end endmodule

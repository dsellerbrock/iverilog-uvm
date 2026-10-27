interface itf; logic c,q,d; modport flop(input c,d, output q); endinterface
module dtype(itf.flop ch); always_ff @(posedge ch.c) ch.q<=ch.d; specify $setup(ch.d, posedge ch.c, 1); endspecify endmodule
module top; itf i(); dtype d(i.flop); endmodule

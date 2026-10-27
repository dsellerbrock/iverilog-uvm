interface itf; logic c,q,d; modport flop(input c,d, output q); endinterface
module dtype(itf.flop ch); always_ff @(posedge ch.c) ch.q<=ch.d; specify (posedge ch.c => (ch.q+:ch.d))=(5,6); endspecify endmodule
module top; itf i(); dtype d(i.flop); endmodule

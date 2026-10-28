interface itf; logic c, q; modport m (input c, ref q); endinterface
module dut (itf.m ch);
  specify (ch.c => ch.q) = (1,1); endspecify
endmodule
module top; itf bus(); dut d(bus); endmodule

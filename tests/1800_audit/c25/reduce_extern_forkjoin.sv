interface fb; int n=0; extern forkjoin task inc(); modport slave(ref n, export inc); initial #1 begin inc; $display("N %0d",n); end endinterface
module mem(fb.slave a); task a.inc(); a.n++; endtask endmodule
module top; fb i(); mem a(i.slave); mem b(i.slave); endmodule

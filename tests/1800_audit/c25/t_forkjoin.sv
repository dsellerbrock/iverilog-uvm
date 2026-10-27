interface sb3(input logic clk); int slaves=0; extern forkjoin task countSlaves();
 modport slave(ref slaves, export countSlaves);
 initial #1 begin countSlaves; $display("SLAVES %0d", slaves); end
endinterface
module memMod(interface a); task a.countSlaves(); a.slaves++; endtask endmodule
module top; logic clk=0; sb3 i(clk); memMod m1(i.slave); memMod m2(i.slave); endmodule

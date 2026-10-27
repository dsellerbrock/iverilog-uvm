interface sb2(input logic clk); logic [7:0] data;
 modport slave(input clk, ref data, export Read);
 modport master(input clk, ref data, import task Read(input logic [7:0] raddr));
endinterface
module memMod(interface a); task a.Read(input logic [7:0] raddr); a.data = raddr + 1; $display("EREAD %0d", raddr); endtask endmodule
module cpuMod(interface b); initial #1 begin b.Read(8'd4); $display("EDATA %0d", b.data); end endmodule
module top; logic clk=0; sb2 i(clk); memMod mem(i.slave); cpuMod cpu(i.master); endmodule

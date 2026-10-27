interface sb #(parameter AW=8, DW=8) (input logic clk);
 logic [AW-1:0] addr; logic [DW-1:0] data; int n = 0;
 modport master(input clk, output addr, ref data, import task mrd(input logic [AW-1:0] raddr), task mwr(input logic [AW-1:0] waddr));
 modport slave(input clk, input addr, ref data, import task srd);
 task mrd(input logic [AW-1:0] raddr); addr = raddr; n++; $display("MRD %h", raddr); endtask
 task mwr(input logic [AW-1:0] waddr); addr = waddr; n += 10; $display("MWR %h", waddr); endtask
 task srd; n += 100; $display("SRD n=%0d", n); endtask
endinterface
module cpu(interface b); initial begin #1 b.mrd(8'h12); b.mwr(8'h34); end endmodule
module mem(interface a); initial #2 a.srd; endmodule
module top; logic clk=0; sb sb_i(clk); sb #(.DW(16)) wide(clk); cpu c(sb_i.master); mem m(sb_i.slave); cpu cw(wide.master);
 initial #3 $display("N %0d %0d W%0d", sb_i.n, wide.n, $bits(wide.data)); endmodule

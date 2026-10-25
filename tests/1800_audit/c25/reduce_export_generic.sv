interface eb; logic [7:0] data; modport slave(ref data, export Read); modport master(ref data, import task Read(input logic [7:0] a)); endinterface
module mem(interface a); task a.Read(input logic [7:0] r); a.data=r; endtask endmodule
module cpu(eb.master b); initial #1 begin b.Read(8'd4); $display("DATA %0d", b.data); end endmodule
module top; eb i(); mem m(i.slave); cpu c(i.master); endmodule

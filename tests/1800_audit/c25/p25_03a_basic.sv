interface simple_bus(input logic clk);
  logic req, gnt;
  logic [7:0] addr, data;
  logic [1:0] mode;
  logic start, rdy;
  modport slave(input req, addr, mode, start, clk, output gnt, rdy, ref data);
  modport master(input gnt, rdy, clk, output req, addr, mode, start, ref data);
endinterface : simple_bus

module memMod(simple_bus.slave a);
  logic avail = 1;
  always @(posedge a.clk) a.gnt <= a.req & avail;
endmodule

module cpuMod(simple_bus.master b);
  initial begin b.req = 0; #15 b.req = 1; end
endmodule

module gen(interface x);
  initial #40 $display("GEN gnt=%b req=%b", x.gnt, x.req);
endmodule

module imp(simple_bus sb_intf);
  initial #1 $display("IMP clk=%b", sb_intf.clk);
endmodule

module top;
  logic clk = 0;
  simple_bus sb_intf(clk);
  simple_bus vec[1:0](clk);
  initial repeat (10) #10 clk++;
  memMod mem(.a(sb_intf));
  cpuMod cpu(.b(sb_intf));
  gen g(.x(sb_intf));
  imp i(.*);
  initial #50 $display("TOP req=%b gnt=%b", sb_intf.req, sb_intf.gnt);
  initial #2 begin
    vec[0].addr = 8'h11;
    vec[1].addr = 8'h22;
    $display("ARR %h %h", vec[0].addr, vec[1].addr);
  end
endmodule

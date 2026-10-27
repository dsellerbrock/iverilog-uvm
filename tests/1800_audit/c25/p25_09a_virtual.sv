interface SBus;
  logic req, grant;
  logic [7:0] addr, data;
endinterface

interface PBus #(parameter WIDTH=8);
  logic req, grant;
  logic [WIDTH-1:0] addr, data;
  modport phy(input addr, ref data);
endinterface

interface SyncBus(input logic clk);
  wire a, b, c;
  clocking sb @(posedge clk);
    input a;
    output b;
    inout c;
  endclocking
endinterface

class SBusTransactor;
  virtual SBus bus;
  function new(virtual SBus s); bus = s; endfunction
  task request(); bus.req <= 1'b1; endtask
  task wait_for_bus(); @(posedge bus.grant); endtask
endclass

module top;
  SBus s[1:4]();
  PBus #(16) p16();
  PBus #(32) p32();
  logic clk = 0;
  SyncBus b1(clk);
  virtual SBus vn;
  virtual SBus vs;
  virtual PBus #(16) v16;
  virtual PBus #(32) v32;
  virtual PBus #(16).phy v16p;
  SBusTransactor t[1:4];
  int pass = 0;
  initial begin
    if (vn == null) $display("NULL_INIT");
    vs = s[2];
    if (vs == s[2] && vs != s[1]) $display("EQ_OK");
    foreach (t[i]) t[i] = new(s[i]);
    fork
      begin t[3].wait_for_bus(); $display("GRANT3 at %0t", $time); end
      begin #5 s[3].grant = 1'b1; end
    join
    t[2].request();
    #1 $display("REQ2 %b REQ1 %b", s[2].req, s[1].req);
    v16 = p16;
    v32 = p32;
    v16p = v16;
    vs.addr = 8'h5A;
    $display("ADDR %h", s[2].addr);
    v16.addr = 16'hBEEF;
    $display("P16 %h", p16.addr);
    vs = null;
    vs = s[4];
    $display("SWITCH %b", vs == s[4]);
    $display("CLK %b", b1.sb.a === 1'bz);
    $display("DONE");
  end
endmodule

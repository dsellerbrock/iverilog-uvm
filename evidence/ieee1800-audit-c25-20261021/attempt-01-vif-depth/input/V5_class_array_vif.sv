`timescale 1ns/1ns
interface SBus;
  logic req, grant;
endinterface
class SBusTransactor;
  virtual SBus bus;
  function new(virtual SBus s);
    bus = s;
  endfunction
  task request();
    bus.req <= 1'b1;
  endtask
endclass
module top;
  SBus s[1:4]();
  SBusTransactor t[1:4];
  initial begin
    t[1] = new(s[1]);
    t[2] = new(s[2]);
    t[1].request();
    #1 $display("%b %b", s[1].req, s[2].req);
  end
endmodule

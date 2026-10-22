`timescale 1ns/1ns
interface wait_if;
  logic b = 1'b0;
  modport drv(input b);
endinterface
class Waiter;
  virtual wait_if.drv vif;
  function new(virtual wait_if.drv v);
    vif = v;
  endfunction
  task run();
    wait (vif.b == 1'b1);
    $display("woke %0t", $time);
  endtask
endclass
module top;
  wait_if bus();
  Waiter w;
  initial begin
    w = new(bus);
    fork w.run(); join_none
    #7 bus.b = 1'b1;
    #1 $finish;
  end
endmodule

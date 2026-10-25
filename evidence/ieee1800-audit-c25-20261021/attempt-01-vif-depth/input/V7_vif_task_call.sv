`timescale 1ns/1ns
interface pif;
  logic [7:0] data;
  task drive(input logic [7:0] v);
    data = v;
  endtask
endinterface
class Driver;
  virtual pif vif;
  function new(virtual pif v);
    vif = v;
  endfunction
  task run();
    vif.drive(8'h5a);
  endtask
endclass
module top;
  pif bus();
  Driver driver;
  initial begin
    driver = new(bus);
    driver.run();
    #1 $display("%h", bus.data);
  end
endmodule

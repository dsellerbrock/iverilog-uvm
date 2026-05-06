// G26: modport import task/function port declarations
// Pre-fix: parse.y emitted "sorry:" for both `import task` and
// `import function` in modport bodies.  This test verifies that
// modport tf ports are accepted without syntax errors.
`timescale 1ns/1ps

interface bus_if(input logic clk);
  logic [7:0] data;
  task send(input logic [7:0] d);
    data = d;
  endtask
  function logic [7:0] recv();
    return data;
  endfunction
  modport driver  (output data, import task send(input logic [7:0] d));
  modport monitor (input  data, import function logic [7:0] recv());
endinterface

module driver_m(bus_if.driver d);
  initial begin end
endmodule

module monitor_m(bus_if.monitor m);
  initial begin end
endmodule

module top;
  logic clk = 0;
  bus_if b(.clk(clk));
  driver_m  drv(.d(b));
  monitor_m mon(.m(b));
  initial begin
    $display("PASS: modport import task/function ports accepted");
    $finish;
  end
endmodule

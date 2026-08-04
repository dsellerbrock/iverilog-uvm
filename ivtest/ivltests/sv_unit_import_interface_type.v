package width_pkg;
  parameter int Width = 13;
endpackage

// Compilation-unit imports are visible in design elements declared after
// the import (IEEE 1800-2017 26.3). This includes an interface when its
// members are elaborated through an interface port type rather than as a
// root design element.
import width_pkg::*;

interface width_if;
  logic [Width-1:0] data;

  modport sink(input data);
endinterface

module width_consumer(width_if.sink bus);
  initial begin
    #1;
    if ($bits(bus.data) != Width)
      $display("FAILED -- interface member width is %0d", $bits(bus.data));
    else
      $display("PASSED");
  end
endmodule

module test;
  width_if bus();
  width_consumer dut(bus);

  initial bus.data = '0;
endmodule

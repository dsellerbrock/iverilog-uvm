`begin_keywords "1800-2012"

// The interface declaration intentionally follows the module that names it.
// This is the source ordering used by OpenTitan's OTBN tracer fileset.
module forward_interface_consumer(late_interface bus);
  initial begin
    #1;
    if (bus.value !== 8'h5a)
      $display("FAILED -- forward interface value was %h", bus.value);
    else
      $display("PASSED");
  end
endmodule

interface late_interface;
  logic [7:0] value;
endinterface

module main;
  late_interface bus();
  forward_interface_consumer consumer(bus);

  initial begin
    bus.value = 8'h5a;
    #2;
    $finish;
  end
endmodule

`end_keywords

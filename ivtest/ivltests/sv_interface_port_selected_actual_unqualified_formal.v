// IEEE 1800-2017/2023 25.5.2: a selected-modport actual may connect to a
// named, unqualified physical interface formal. The formal retains the
// actual instance's complete parameter specialization.
interface physical_selected_if #(parameter int WIDTH = 8);
  logic [WIDTH-1:0] payload;
  logic accepted;
  modport sink(input payload, output accepted);
endinterface

module physical_unqualified_formal(physical_selected_if bus);
  initial begin
    #1;
    if ($bits(bus.payload) != 17 || bus.payload !== 17'h1a55a)
      $fatal(1, "formal lost selected actual specialization");
    bus.accepted = 1'b1;
  end
endmodule

module sv_interface_port_selected_actual_unqualified_formal;
  physical_selected_if #(.WIDTH(17)) bus();
  physical_unqualified_formal dut(.bus(bus.sink));

  initial begin
    bus.payload = 17'h1a55a;
    #2;
    if (bus.accepted !== 1'b1)
      $fatal(1, "unqualified formal did not bind selected actual");
    $display("PASSED");
  end
endmodule

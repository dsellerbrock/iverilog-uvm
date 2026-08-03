package empty_parameter_port_pkg;
  parameter int Width = 4;
endpackage

module empty_parameter_port_leaf
  import empty_parameter_port_pkg::*;
#(
) (
  input  logic [Width-1:0] data_i,
  output logic [Width-1:0] data_o
);
  assign data_o = data_i;
endmodule

interface empty_parameter_port_if #();
  logic marker;
endinterface

module empty_parameter_port_list_test;
  logic [3:0] data_o;
  empty_parameter_port_if bus();
  empty_parameter_port_leaf #() dut(.data_i(4'ha), .data_o(data_o));

  initial begin
    bus.marker = 1'b1;
    #1;
    if (data_o !== 4'ha || bus.marker !== 1'b1)
      $fatal(1, "empty parameter-port list changed declaration semantics");
    $display("PASS: empty parameter-port lists");
  end
endmodule

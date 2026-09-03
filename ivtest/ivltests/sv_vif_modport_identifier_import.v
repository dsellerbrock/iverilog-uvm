// IEEE 1800-2017/2023 25.7: an identifier-form import uses the interface
// declaration's signature for positional calls. Named binding or omitted
// defaults still require a full prototype and are covered by the negative
// prototype regression.
interface identifier_import_if #(parameter int WIDTH = 8);
  logic [WIDTH-1:0] seen;

  task automatic drive(input logic [WIDTH-1:0] value);
    seen = value;
  endtask

  function automatic logic [WIDTH-1:0] add(
      input logic [WIDTH-1:0] lhs,
      input logic [WIDTH-1:0] rhs);
    return lhs + rhs;
  endfunction

  function automatic int identity(input int value);
    return value;
  endfunction

  // A full modport prototype shall match the interface declaration under
  // 25.7/6.22.1; equivalent integral representations are not sufficient.
  modport selected(import drive, add,
      import function int identity(input int value));
endinterface

module sv_vif_modport_identifier_import;
  identifier_import_if #(.WIDTH(17)) bus();
  virtual interface identifier_import_if #(17).selected vif;
  logic [16:0] result;
  int identity_result;

  initial begin
    vif = bus.selected;
    vif.drive(17'h12345);
    result = vif.add(17'h10000, 17'h00023);
    identity_result = vif.identity(32'sh1234_5678);
    if (bus.seen !== 17'h12345 || result !== 17'h10023
        || identity_result !== 32'sh1234_5678)
      $fatal(1, "identifier-form import lost declaration signature");
    $display("PASSED");
  end
endmodule

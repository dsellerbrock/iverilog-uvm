// A statically bound interface net member must not alias an invalid owner
// index to canonical word zero. One-element arrays are especially important:
// their physical pin count is one even though an owner index is still
// required and must be valid.
interface oob_instance_if;
  wire [7:0] value;
  modport driver(output value);
endinterface

module oob_instance_driver(
  oob_instance_if.driver buses [0:0],
  input logic [7:0] source
);
  assign buses[1].value = source;
endmodule

module sv_interface_member_contassign_oob_instance_fail;
  oob_instance_if buses [0:0] ();
  logic [7:0] source;

  oob_instance_driver dut(.buses(buses), .source(source));
endmodule

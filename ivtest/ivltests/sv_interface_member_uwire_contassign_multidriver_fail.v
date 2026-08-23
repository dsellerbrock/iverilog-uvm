// A statically-bound interface uwire member retains the unresolved-net
// single-driver rule when its continuous drivers are connected after module
// port binding. The second complete-member driver must be rejected.
interface unresolved_member_if;
  uwire single_driver;
endinterface

module unresolved_member_drivers(
  unresolved_member_if bus,
  input logic first,
  input logic second
);
  assign bus.single_driver = first;
  assign bus.single_driver = second;
endmodule

module sv_interface_member_uwire_contassign_multidriver_fail;
  unresolved_member_if bus();
  logic first;
  logic second;

  unresolved_member_drivers dut(
    .bus(bus),
    .first(first),
    .second(second)
  );
endmodule

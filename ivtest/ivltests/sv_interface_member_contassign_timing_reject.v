// Interface-member l-values currently use an event-driven compatibility
// lowering. Delay and non-default strength cannot be silently discarded:
// reject these unsupported forms explicitly until that lowering can preserve
// their complete continuous-assignment semantics.
interface member_lvalue_if;
  logic delayed;
  logic strength_driven;
  logic explicit_zero;
endinterface

module member_lvalue_driver(input logic source, member_lvalue_if bus);
  assign #1 bus.delayed = source;
  assign (weak1, weak0) bus.strength_driven = source;
  assign #0 bus.explicit_zero = source;
endmodule

module sv_interface_member_contassign_timing_reject;
  logic source;
  member_lvalue_if bus();
  member_lvalue_driver dut(.source(source), .bus(bus));
endmodule

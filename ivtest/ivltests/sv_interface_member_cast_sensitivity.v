// IEEE 1800-2017 6.24.1 / 10.7 / 25.5: an explicit cast does not
// remove the dependencies of its operand.  In particular, a continuous
// assignment that reads an interface or modport member through a type,
// size, or sign cast must both elaborate and re-evaluate whenever that
// member changes.
//
// Interface members are represented internally as handle properties.  The
// special continuous-assignment lowering therefore walks the parsed r-value
// to find the real member reads used for event sensitivity.  This test keeps
// casts at the dependency boundary and changes one source at a time after
// time zero, so accepting the expressions without wiring every dependency is
// still a runtime failure.  The packed-struct enum assignment is the
// Caliptra axi_sub_wr shape that exposed the type-cast gap.
// `sv_enum_whole_continuous_assign_fail' remains the active negative control
// proving that the corresponding integral-to-enum assignment needs this cast.

typedef enum logic [1:0] {
  BURST_FIXED = 2'b00,
  BURST_INCR  = 2'b01,
  BURST_WRAP  = 2'b10
} burst_e;

typedef logic [7:0] byte_t;
typedef logic [3:0] nibble_t;

typedef struct packed {
  logic [2:0] tag;
  burst_e     burst;
} request_context_t;

interface cast_bus_if;
  logic        [1:0] burst_raw;
  logic        [3:0] raw;
  logic        [3:0] alt;
  logic signed [3:0] signed_raw;
  logic              select;
  logic        [3:0] mirrored;
  logic        [3:0] seeded = 4'h5;
  logic        [3:0] seeded_mirrored;

  modport source (input burst_raw, raw, alt, signed_raw, select, seeded,
                  output mirrored, seeded_mirrored);
endinterface

module modport_cast_reader(
  cast_bus_if.source       bus,
  output logic       [1:0] burst_bits,
  output logic       [7:0] type_value,
  output logic       [7:0] size_value,
  output logic signed [7:0] signed_value,
  output logic       [7:0] unsigned_value,
  output logic       [7:0] binary_value,
  output logic       [7:0] ternary_value,
  output logic       [7:0] concat_value
);
  request_context_t ctx;

  // Explicit enum/type casts directly around a modport member.  The first
  // assignment deliberately targets a packed-struct enum field.
  assign ctx.burst  = burst_e'(bus.burst_raw);
  assign burst_bits = ctx.burst;
  assign type_value    = byte_t'(bus.raw);

  // Size and sign casts retain the member read as a sensitivity source.
  assign size_value     = 8'(bus.alt);
  assign signed_value   = signed'(bus.raw);
  assign unsigned_value = unsigned'(bus.signed_raw);

  // Walk through the common nested expression nodes on the way to the
  // interface-member leaves: binary, ternary, and concatenation.
  assign binary_value  = byte_t'(bus.raw + bus.alt);
  assign ternary_value = byte_t'(bus.select ? bus.raw : bus.alt);
  assign concat_value  = 8'({bus.raw, bus.alt});

  // Also exercise the interface-member l-value lowering.  Both operands
  // underneath the outer type cast must independently retrigger this store.
  assign bus.mirrored = nibble_t'(bus.raw ^ bus.alt);

  // Pin lazy any-change probe initialization.  The first change after the
  // process starts is known-to-X; a probe left at its default X value would
  // miss it and leave this destination at 5.
  assign bus.seeded_mirrored = nibble_t'(bus.seeded);
endmodule

// An unqualified interface port takes the same property-read path as the
// modport-qualified port above.  Keep a direct type-cast case for that form.
module interface_cast_reader(
  cast_bus_if       bus,
  output logic [7:0] value
);
  assign value = byte_t'(bus.raw);
endmodule

// Exercise the `%wait/vif/anyedge/multi' path used by an explicit compound
// event.  Every transition below changes the expression result as well as an
// upper vector bit, so this remains an exact event-expression oracle while
// repeatedly arming and removing the sibling member registrations.
module compound_event_reader(cast_bus_if.source bus);
  integer wakes = 0;
  always @(bus.raw == 4'hd || bus.alt == 4'h8)
    wakes = wakes + 1;
endmodule

module sv_interface_member_cast_sensitivity;
  cast_bus_if bus();
  cast_bus_if event_bus();

  logic       [1:0] burst_bits;
  logic       [7:0] type_value;
  logic       [7:0] size_value;
  logic signed [7:0] signed_value;
  logic       [7:0] unsigned_value;
  logic       [7:0] binary_value;
  logic       [7:0] ternary_value;
  logic       [7:0] concat_value;
  logic       [7:0] interface_value;
  int errors = 0;
  int wake_base;

  modport_cast_reader modport_reader(
    bus.source, burst_bits, type_value, size_value, signed_value,
    unsigned_value, binary_value, ternary_value, concat_value
  );
  interface_cast_reader interface_reader(bus, interface_value);
  compound_event_reader compound_reader(event_bus.source);

  `define CHECK_CAST_VALUE(actual, expected, label) \
    if ((actual) !== (expected)) begin \
      $display("FAILED -- %s: got %h, expected %h", \
               label, actual, expected); \
      errors++; \
    end

  initial begin
    bus.burst_raw  = 2'b01;
    bus.raw        = 4'h1;
    bus.alt        = 4'h2;
    bus.signed_raw = 4'he;
    bus.select     = 1'b1;
    event_bus.raw  = 4'h1;
    event_bus.alt  = 4'h0;
    #1;
    `CHECK_CAST_VALUE(burst_bits,       2'h1,  "initial enum type cast")
    `CHECK_CAST_VALUE(type_value,       8'h01, "initial vector type cast")
    `CHECK_CAST_VALUE(size_value,       8'h02, "initial size cast")
    `CHECK_CAST_VALUE(signed_value,     8'h01, "initial signed cast")
    `CHECK_CAST_VALUE(unsigned_value,   8'h0e, "initial unsigned cast")
    `CHECK_CAST_VALUE(binary_value,     8'h03, "initial nested binary")
    `CHECK_CAST_VALUE(ternary_value,    8'h01, "initial nested ternary")
    `CHECK_CAST_VALUE(concat_value,     8'h12, "initial nested concat")
    `CHECK_CAST_VALUE(bus.mirrored,     4'h3,  "initial interface l-value")
    `CHECK_CAST_VALUE(bus.seeded_mirrored, 4'h5, "initial seeded member")
    `CHECK_CAST_VALUE(interface_value,  8'h01, "initial plain interface")

    wake_base = compound_reader.wakes;
    event_bus.raw = 4'h1;
    #1;
    `CHECK_CAST_VALUE(compound_reader.wakes, wake_base,
                      "compound unchanged write")
    event_bus.raw = 4'hd;
    #1;
    `CHECK_CAST_VALUE(compound_reader.wakes, wake_base + 1,
                      "compound raw upper-bit wake")
    event_bus.raw = 4'h1;
    #1;
    `CHECK_CAST_VALUE(compound_reader.wakes, wake_base + 2,
                      "compound raw re-arm")
    event_bus.alt = 4'h8;
    #1;
    `CHECK_CAST_VALUE(compound_reader.wakes, wake_base + 3,
                      "compound alt upper-bit wake")
    event_bus.alt = 4'h0;
    #1;
    `CHECK_CAST_VALUE(compound_reader.wakes, wake_base + 4,
                      "compound alt re-arm")

    // Change only raw.  Both values keep bit 0 high, so this also proves
    // that virtual-interface any-change waits observe the complete vector
    // rather than only its least-significant bit.  Every raw-dependent cast
    // must re-evaluate without being masked by an event from another operand.
    bus.raw = 4'hd;
    #1;
    `CHECK_CAST_VALUE(burst_bits,      2'h1,  "unrelated raw leaves enum stable")
    `CHECK_CAST_VALUE(type_value,      8'h0d, "raw type update")
    `CHECK_CAST_VALUE(signed_value,    8'hfd, "raw signed update")
    `CHECK_CAST_VALUE(binary_value,    8'h0f, "raw binary update")
    `CHECK_CAST_VALUE(ternary_value,   8'h0d, "raw ternary update")
    `CHECK_CAST_VALUE(concat_value,    8'hd2, "raw concat update")
    `CHECK_CAST_VALUE(bus.mirrored,    4'hf,  "raw interface-lvalue update")
    `CHECK_CAST_VALUE(interface_value, 8'h0d, "raw plain-interface update")

    // Change only alt while raw remains stable.  This independently pins
    // the second leaf found beneath binary and concat nodes.
    bus.alt = 4'h1;
    #1;
    `CHECK_CAST_VALUE(size_value,     8'h01, "alt size update")
    `CHECK_CAST_VALUE(binary_value,   8'h0e, "alt binary update")
    `CHECK_CAST_VALUE(concat_value,   8'hd1, "alt concat update")
    `CHECK_CAST_VALUE(bus.mirrored,   4'hc,  "alt interface-lvalue update")

    // The ternary condition is a third independent interface-member read.
    bus.select = 1'b0;
    #1;
    `CHECK_CAST_VALUE(ternary_value, 8'h01, "selector update")

    // With the false arm selected, changing only alt must retrigger the
    // ternary as well as all other alt-dependent expressions.
    bus.alt = 4'h0;
    #1;
    `CHECK_CAST_VALUE(size_value,     8'h00, "selected alt size update")
    `CHECK_CAST_VALUE(binary_value,   8'h0d, "selected alt binary update")
    `CHECK_CAST_VALUE(ternary_value,  8'h00, "selected alt ternary update")
    `CHECK_CAST_VALUE(concat_value,   8'hd0, "selected alt concat update")
    `CHECK_CAST_VALUE(bus.mirrored,   4'hd,  "selected alt l-value update")

    // Sign-cast dependency on a signed interface member, changed alone.
    bus.signed_raw = 4'h9;
    #1;
    `CHECK_CAST_VALUE(unsigned_value, 8'h09, "signed member update")

    // The native two-bit interface member in the enum cast is an independent
    // dependency (the exact Caliptra axi_burst_e'(s_axi_if.awburst) shape).
    bus.burst_raw = 2'b10;
    #1;
    `CHECK_CAST_VALUE(burst_bits, 2'h2, "post-time-zero enum update")

    // Finish on a negative signed cast while the new enum value stays stable.
    bus.raw = 4'he;
    #1;
    `CHECK_CAST_VALUE(burst_bits,      2'h2,  "final enum update")
    `CHECK_CAST_VALUE(type_value,      8'h0e, "final type update")
    `CHECK_CAST_VALUE(signed_value,    8'hfe, "final signed update")
    `CHECK_CAST_VALUE(binary_value,    8'h0e, "final binary update")
    `CHECK_CAST_VALUE(ternary_value,   8'h00, "final ternary value")
    `CHECK_CAST_VALUE(concat_value,    8'he0, "final concat update")
    `CHECK_CAST_VALUE(bus.mirrored,    4'he,  "final interface-lvalue update")
    `CHECK_CAST_VALUE(interface_value, 8'h0e, "final plain-interface update")

    bus.seeded = 4'hx;
    #1;
    `CHECK_CAST_VALUE(bus.seeded_mirrored, 4'hx,
                      "first seeded known-to-X update")

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

  `undef CHECK_CAST_VALUE
endmodule

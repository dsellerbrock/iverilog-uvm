`begin_keywords "1800-2012"

// Caliptra's AXI adapters use all of these interface-member continuous-
// assignment shapes. Simulation needs one watcher per source expression,
// while synthesis must lower the assignment exactly once as combinational
// hardware (IEEE 1800-2017 10.6 and 25.3).
interface contassign_if;
  logic a;
  logic b;
  logic c;
  logic [3:0] vec;
  logic multi;
  logic selected;
  logic constant_zero;
  logic [1:0] response;
  logic [7:0] id;

  modport dut(
    input a, b, c, vec,
    output multi, selected, constant_zero, response, id
  );
endinterface

module contassign_take3(
  input wire [2:0] i_data,
  output wire [2:0] o_data
);
  assign o_data = i_data;
endmodule

module contassign_give10(
  input wire [9:0] i_data,
  output wire [9:0] o_data
);
  assign o_data = i_data;
endmodule

module contassign_shapes(
  input logic x,
  input logic [9:0] produced,
  contassign_if.dut bus,
  output wire [2:0] consumed,
  output wire direct_read
);
  // Mixed ordinary/interface reads and more than one interface read.
  assign bus.multi = x && (bus.a || bus.b);

  // A selected RHS has a narrower event probe than its packed base.
  assign bus.selected = bus.vec[1];

  // An ordinary net destination still needs continuous net semantics even
  // though the interface-member source is read through an event-driven proxy.
  assign direct_read = bus.a ^ bus.c;

  // A constant drive has no behavioral watcher, but is still hardware.
  assign bus.constant_zero = '0;

  // Input and output port bridges with concatenated interface members.
  contassign_take3 take3(.i_data({bus.a, bus.b, bus.c}),
                         .o_data(consumed));
  contassign_give10 give10(.i_data(produced),
                           .o_data({bus.response, bus.id}));
endmodule

module synth_interface_member_contassign_shapes;
  contassign_if bus();
  logic x;
  logic [9:0] produced;
  wire [2:0] consumed;
  wire direct_read;

  contassign_shapes dut(.x(x), .produced(produced), .bus(bus),
                        .consumed(consumed), .direct_read(direct_read));

  (* ivl_synthesis_off *)
  initial begin
    x = 1'b1;
    bus.a = 1'b0;
    bus.b = 1'b1;
    bus.c = 1'b0;
    bus.vec = 4'b0010;
    produced = 10'h2a5;
    #1;
    if ({bus.multi, bus.selected, bus.constant_zero, direct_read, consumed,
         bus.response, bus.id} !== {4'b1100, 3'b010, 10'h2a5})
      $fatal(1, "first result: %b %b %b %b %b %b %b",
             bus.multi, bus.selected, bus.constant_zero, direct_read, consumed,
             bus.response, bus.id);

    x = 1'b0;
    bus.a = 1'b1;
    bus.b = 1'b0;
    bus.c = 1'b1;
    bus.vec = 4'b0000;
    produced = 10'h155;
    #1;
    if ({bus.multi, bus.selected, bus.constant_zero, direct_read, consumed,
         bus.response, bus.id} !== {4'b0000, 3'b101, 10'h155})
      $fatal(1, "second result: %b %b %b %b %b %b %b",
             bus.multi, bus.selected, bus.constant_zero, direct_read, consumed,
             bus.response, bus.id);

    // Prove that each source remains reactive in ordinary simulation and
    // that the synthesized representative is truly combinational.
    x = 1'b1;
    bus.a = 1'b0;
    bus.b = 1'b0;
    #1;
    if (bus.multi !== 1'b0 || direct_read !== 1'b1)
      $fatal(1, "before source update: multi=%b direct=%b",
             bus.multi, direct_read);
    bus.a = 1'b1;
    #1;
    if (bus.multi !== 1'b1 || direct_read !== 1'b0)
      $fatal(1, "after source update: multi=%b direct=%b",
             bus.multi, direct_read);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

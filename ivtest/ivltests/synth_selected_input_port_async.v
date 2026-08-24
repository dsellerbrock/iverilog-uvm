`begin_keywords "1800-2012"

typedef struct packed {
  logic [4:0] data;
  logic       valid;
} selected_input_payload_t;

module selected_input_star_leaf (
  input  logic [4:0] in,
  output logic       parity
);
  // A parent part-select or packed member is an ordinary directional port
  // connection. It must not be mistaken for the private part-select that
  // implements precise implicit sensitivity inside this process.
  always @* parity = ^in;
endmodule

module main;
  logic [7:0]              bus;
  selected_input_payload_t payload;
  logic [4:0]              whole;
  wire                     part_parity;
  wire                     field_parity;
  wire                     whole_parity;

  selected_input_star_leaf from_part (
    .in     (bus[4:0]),
    .parity (part_parity)
  );

  selected_input_star_leaf from_field (
    .in     (payload.data),
    .parity (field_parity)
  );

  // Whole-net control: the leaf process and its synthesis are otherwise the
  // same as the two selected-port cases above.
  selected_input_star_leaf from_whole (
    .in     (whole),
    .parity (whole_parity)
  );

  (* ivl_synthesis_off *)
  initial begin
    bus = 8'b1010_1101;
    payload.data = 5'b10110;
    payload.valid = 1'b0;
    whole = 5'b00111;
    #1;
    if ({part_parity, field_parity, whole_parity} !== 3'b111)
      $fatal(1, "first parity mismatch: %b %b %b",
             part_parity, field_parity, whole_parity);

    bus[4:0] = 5'b11110;
    payload.data = 5'b11111;
    whole = 5'b10100;
    #1;
    if ({part_parity, field_parity, whole_parity} !== 3'b010)
      $fatal(1, "second parity mismatch: %b %b %b",
             part_parity, field_parity, whole_parity);

    $display("PASSED");
  end
endmodule

`end_keywords

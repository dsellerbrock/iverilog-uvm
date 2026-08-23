`begin_keywords "1800-2012"

interface compound_port_if;
  logic [7:0] value;
  logic [7:0] lanes [0:1];

  modport driver(output value, lanes);
endinterface

module compound_port_array_driver(
  compound_port_if.driver ports [0:1],
  input logic [7:0] in0,
  input logic [7:0] in1
);
  // The word select on `ports` chooses a statically bound interface instance;
  // it is not a dynamic/object carrier word. A separate word on the resolved
  // member array is likewise an ordinary static unpacked-array selection.
  always_comb begin
    ports[0].value = in0;
    ports[0].value |= 8'h01;
    ports[1].value = in1;
    ports[1].value |= 8'h80;

    ports[0].lanes[1] = in0;
    ports[0].lanes[1] ^= 8'hff;
    ports[1].lanes[0] = in1;
    ports[1].lanes[0] &= 8'hf0;
  end
endmodule

module main;
  typedef struct packed {
    logic [3:0] hi;
    struct packed {
      logic [7:0] value;
    } nested;
    logic [3:0] lo;
  } packed_t;

  typedef struct packed {
    logic [7:0] data;
    logic       error;
    logic       intentionally_unassigned;
  } response_t;

  logic [7:0] words [0:3];
  logic [7:0] mask;
  logic [7:0] reduced;
  logic [7:0] array_word;
  logic [7:0] default_then_conditional;
  logic [7:0] complete_branches;
  logic [15:0] packed_result;
  response_t [1:0] packed_responses;
  logic [1:0] error_terms;
  logic [7:0] scratch [0:3];
  logic [7:0] interface_in0;
  logic [7:0] interface_in1;
  logic choose;

  compound_port_if compound_bus [0:1] ();
  compound_port_array_driver compound_driver(
    .ports(compound_bus), .in0(interface_in0), .in1(interface_in1));

  // PeakRDL-generated register blocks accumulate readback data with this
  // automatic-local, array-reduction pattern.
  always_comb begin
    automatic logic [7:0] accum;

    accum = '0;
    for (int i = 0; i < 4; i++)
      accum |= words[i];
    reduced = accum;
  end

  // Compound assignments to packed members must read the selected bits from
  // the current procedural carrier and then reinsert the updated value.
  always_comb begin
    automatic packed_t tmp;

    tmp = 16'h1234;
    tmp.nested.value |= mask;
    packed_result = tmp;
  end

  // A loop index is contextually constant in each synthesized iteration.
  always_comb begin
    for (int i = 0; i < 4; i++) begin
      scratch[i] = 8'h10;
      scratch[i] |= words[i];
    end
    array_word = scratch[2];
  end

  // Caliptra's kv/pv response muxes initialize and reduce selected fields of
  // packed arrays independently. The neighboring field deliberately remains
  // invalid: synthesis must prove that the selected data/error bits have a
  // prior value without requiring the complete packed carrier to be valid.
  always_comb begin
    for (int client = 0; client < 2; client++) begin
      packed_responses[client].data = 8'h10;
      packed_responses[client].error = 1'b0;
      for (int entry = 0; entry < 4; entry++) begin
        packed_responses[client].data |= words[entry];
        packed_responses[client].error |=
            error_terms[entry[0]] & (entry == client);
      end
    end
  end

  // A conditional update preserves a complete value established before the
  // branch, and a conditional whose two branches both assign establishes one.
  always_comb begin
    automatic logic [7:0] tmp;

    tmp = 8'h10;
    if (choose)
      tmp = 8'h20;
    tmp |= mask;
    default_then_conditional = tmp;
  end

  always_comb begin
    automatic logic [7:0] tmp;

    if (choose)
      tmp = 8'h40;
    else
      tmp = 8'h08;
    tmp |= mask;
    complete_branches = tmp;
  end

  (* ivl_synthesis_off *)
  initial begin
    words[0] = 8'h01;
    words[1] = 8'h20;
    words[2] = 8'h04;
    words[3] = 8'h80;
    mask = 8'h81;
    error_terms = 2'b10;
    interface_in0 = 8'h34;
    interface_in1 = 8'h2f;
    choose = 1'b0;
    #1;
    if ({reduced, packed_result, array_word,
         default_then_conditional, complete_branches}
        !== {8'ha5, 16'h1a34, 8'h14, 8'h91, 8'h89})
      $fatal(1, "first result: %h %h %h %h %h",
             reduced, packed_result, array_word,
             default_then_conditional, complete_branches);
    if ({packed_responses[1].data, packed_responses[1].error,
         packed_responses[0].data, packed_responses[0].error}
        !== {8'hb5, 1'b1, 8'hb5, 1'b0})
      $fatal(1, "first selected packed carriers: %h %b %h %b",
             packed_responses[1].data, packed_responses[1].error,
             packed_responses[0].data, packed_responses[0].error);
    if ({packed_responses[1].intentionally_unassigned,
         packed_responses[0].intentionally_unassigned} !== 2'bxx)
      $fatal(1, "neighboring fields unexpectedly assigned");
    if ({compound_bus[0].value, compound_bus[1].value,
         compound_bus[0].lanes[1], compound_bus[1].lanes[0]}
        !== {8'h35, 8'haf, 8'hcb, 8'h20})
      $fatal(1, "interface compound carriers: %h %h %h %h",
             compound_bus[0].value, compound_bus[1].value,
             compound_bus[0].lanes[1], compound_bus[1].lanes[0]);

    words[2] = 8'h42;
    mask = 8'h0c;
    error_terms = 2'b01;
    interface_in0 = 8'h80;
    interface_in1 = 8'h71;
    choose = 1'b1;
    #1;
    if ({reduced, packed_result, array_word,
         default_then_conditional, complete_branches}
        !== {8'he3, 16'h12f4, 8'h52, 8'h2c, 8'h4c})
      $fatal(1, "updated result: %h %h %h %h %h",
             reduced, packed_result, array_word,
             default_then_conditional, complete_branches);
    if ({packed_responses[1].data, packed_responses[1].error,
         packed_responses[0].data, packed_responses[0].error}
        !== {8'hf3, 1'b0, 8'hf3, 1'b1})
      $fatal(1, "updated selected packed carriers: %h %b %h %b",
             packed_responses[1].data, packed_responses[1].error,
             packed_responses[0].data, packed_responses[0].error);
    if ({packed_responses[1].intentionally_unassigned,
         packed_responses[0].intentionally_unassigned} !== 2'bxx)
      $fatal(1, "neighboring fields unexpectedly assigned after update");
    if ({compound_bus[0].value, compound_bus[1].value,
         compound_bus[0].lanes[1], compound_bus[1].lanes[0]}
        !== {8'h81, 8'hf1, 8'h7f, 8'h70})
      $fatal(1, "updated interface compound carriers: %h %h %h %h",
             compound_bus[0].value, compound_bus[1].value,
             compound_bus[0].lanes[1], compound_bus[1].lanes[0]);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

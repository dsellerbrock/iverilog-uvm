`begin_keywords "1800-2012"

module main;
  logic [7:0] source;
  logic [7:0] routed;
  logic [7:0] grouped;
  logic [5:0] selected;
  logic       choose_source;

  // OpenTitan arbitration trees generate separate combinational processes for
  // disjoint bits and fields of one packed vector. Each synthesized process
  // must drive Z outside its own field so the complete value composes without
  // inventing a latch or hiding a genuine overlapping writer.
  for (genvar bit_idx = 0; bit_idx < 8; bit_idx++) begin : gen_route
    always_comb routed[bit_idx] = source[bit_idx];
  end

  for (genvar pair_idx = 0; pair_idx < 4; pair_idx++) begin : gen_group
    always_comb begin
      grouped[2*pair_idx +: 2] = source[2*pair_idx +: 2];
    end
  end

  // A condition does not imply a latch when every branch assigns the same
  // field. This is the Ibex shift_amt shape: one independently driven bit and
  // a lower field selected by a complete if/else.
  assign selected[5] = source[5];
  always_comb begin
    if (choose_source)
      selected[4:0] = source[4:0];
    else
      selected[4:0] = ~source[4:0];
  end

  task automatic fail(input string label);
    $display("FAILED -- %s source=%h routed=%h grouped=%h selected=%h",
             label, source, routed, grouped, selected);
    $finish;
  endtask

  (* ivl_synthesis_off *)
  initial begin
    source = 8'h96;
    choose_source = 1'b1;
    #1;
    if (routed !== source || grouped !== source || selected !== source[5:0])
      fail("first composed value");

    source = 8'h69;
    choose_source = 1'b0;
    #1;
    if (routed !== source || grouped !== source ||
        selected !== {source[5], ~source[4:0]})
      fail("updated composed value");

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

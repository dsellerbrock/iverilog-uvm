`begin_keywords "1800-2012"

module precise_implicit_leaf (
  input  logic [7:0] in,
  output logic       parity
);
  // A selected read inside always_comb remains a supported control. Exact
  // selected-bit wakeup behavior is observed separately by the existing
  // sv_always_comb_precise_select_sens regression; this synthesis test does
  // not infer dependency provenance from netlist topology.
  always_comb parity = ^in[4:0];
endmodule

module whole_input_star_leaf (
  input  logic [4:0] in,
  output logic       parity
);
  always @* parity = ^in;
endmodule

module selected_input_comb_leaf (
  input  logic [4:0] in,
  output logic       parity
);
  // always_comb's time-zero event is an independent control for a selected
  // parent connection.
  always_comb parity = ^in;
endmodule

module main;
  logic [7:0] precise_source;
  logic [7:0] selected_source;
  logic [4:0] whole_source;
  wire        precise_parity;
  wire        selected_comb_parity;
  wire        whole_parity;

  precise_implicit_leaf precise (
    .in     (precise_source),
    .parity (precise_parity)
  );

  selected_input_comb_leaf selected_comb (
    .in     (selected_source[6:2]),
    .parity (selected_comb_parity)
  );

  whole_input_star_leaf whole_star (
    .in     (whole_source),
    .parity (whole_parity)
  );

  (* ivl_synthesis_off *)
  initial begin
    precise_source = 8'b1110_1101;
    selected_source = 8'b0111_1000;
    whole_source = 5'b01110;
    #1;
    if ({precise_parity, selected_comb_parity, whole_parity} !== 3'b101)
      $fatal(1, "first control mismatch: %b %b %b",
             precise_parity, selected_comb_parity, whole_parity);

    precise_source[4:0] = 5'b11111;
    selected_source[6:2] = 5'b10101;
    whole_source = 5'b11110;
    #1;
    if ({precise_parity, selected_comb_parity, whole_parity} !== 3'b110)
      $fatal(1, "second control mismatch: %b %b %b",
             precise_parity, selected_comb_parity, whole_parity);

    $display("PASSED");
  end
endmodule

`end_keywords

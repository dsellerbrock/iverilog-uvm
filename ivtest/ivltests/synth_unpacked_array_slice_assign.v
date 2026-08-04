`begin_keywords "1800-2012"

module main;
  typedef struct packed {
    logic       tmp_wr_en;
    logic       clear_en;
    logic [3:0] tag;
  } control_t;

  localparam control_t ControlDefault = '0;

  control_t control_mod[3];
  control_t control_multi[2][4];
  logic [7:0] descending[2][3:1];

  // OpenTitan OTBN builds two rows of packed-structure control words this
  // way. A partial index of the 2-D unpacked array is a four-word slice, not
  // a one-bit selected word. Later scalar-word writes must override the
  // corresponding default words in statement order.
  always_comb begin
    control_multi[1] = '{default: ControlDefault};
    for (int unsigned cycle = 0; cycle < 3; cycle++)
      control_multi[1][cycle] = control_mod[cycle];

    // The assignment-pattern elaborator already maps declared direction to
    // canonical pin order. Synthesis must not reverse this slice again.
    descending[0] = '{default: 8'h00};
    descending[1] = '{8'h31, 8'h22, 8'h13};
  end

  (* ivl_synthesis_off *)
  initial begin
    control_mod[0] = 6'h01;
    control_mod[1] = 6'h12;
    control_mod[2] = 6'h23;

    #1;
    if (control_multi[1][0] !== 6'h01 ||
        control_multi[1][1] !== 6'h12 ||
        control_multi[1][2] !== 6'h23 ||
        control_multi[1][3] !== 6'h00) begin
      $display("FAILED -- slice fill/override or row isolation");
      $finish;
    end

    if (descending[0][3] !== 8'h00 ||
        descending[0][2] !== 8'h00 ||
        descending[0][1] !== 8'h00 ||
        descending[1][3] !== 8'h31 ||
        descending[1][2] !== 8'h22 ||
        descending[1][1] !== 8'h13) begin
      $display("FAILED -- descending slice order");
      $finish;
    end

    control_mod[0] = 6'h3c;
    #1;
    if (control_multi[1][0] !== 6'h3c ||
        control_multi[1][3] !== 6'h00) begin
      $display("FAILED -- combinational slice update");
      $finish;
    end

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

`begin_keywords "1800-2012"

module main;
  localparam int N_ALERTS = 4;
  localparam int N_CLASSES = 2;
  localparam int CLASS_DW = 1;

  logic [N_ALERTS-1:0][CLASS_DW-1:0] alert_class;
  logic [N_CLASSES-1:0][N_ALERTS-1:0] class_masks;
  logic [2:0] direct_index;
  logic [7:0] direct_out;
  logic [2:0] part_index;
  logic [7:0] part_out;
  logic [7:0] down_part_out;
  logic signed [3:0] signed_part_index;
  logic [7:0] signed_part_out;
  logic signed [64:0] wide_signed_part_index;
  logic [3:0] wide_part_data;
  logic [1:0] wide_signed_part_out;
  logic [3:0] ranged_index;
  logic [15:8] ranged_out;
  logic [2:0] ascending_index;
  logic [0:7] ascending_out;
  logic [7:0] expected;
  integer i;

  always_comb begin
    direct_out = '0;
    direct_out[direct_index] = 1'b1;
  end

  always_comb begin
    part_out = 8'ha5;
    part_out[part_index +: 2] = 2'b10;
  end

  always_comb begin
    down_part_out = 8'ha4;
    down_part_out[part_index -: 2] = 2'b10;
  end

  always_comb begin
    signed_part_out = 8'ha5;
    signed_part_out[signed_part_index +: 2] = 2'b01;
  end

  always_comb begin
    wide_signed_part_out = '0;
    wide_signed_part_out[wide_signed_part_index +: 4] = wide_part_data;
  end

  always_comb begin
    ranged_out = '0;
    ranged_out[ranged_index] = 1'b1;
    ascending_out = '0;
    ascending_out[ascending_index] = 1'b1;
  end

  always_comb begin
    class_masks = '0;
    for (int unsigned k = 0; k < N_ALERTS; k++) begin
      class_masks[alert_class[k]][k] = 1'b1;
    end
  end

  task automatic fail(input string label);
    $display("FAILED -- %s", label);
    $finish;
  endtask

  (* ivl_synthesis_off *)
  initial begin
    direct_index = 3'd5;
    #1;
    if (direct_out !== 8'b0010_0000)
      fail("direct run-time bit index");

    part_index = 3'd3;
    #1;
    if (part_out !== 8'hb5)
      fail("run-time indexed part select");

    if (down_part_out !== 8'ha8)
      fail("run-time downward indexed part select");

    part_index = 3'd7;
    #1;
    if (part_out !== 8'h25)
      fail("partially high out-of-range indexed part select");

    part_index = 3'd0;
    #1;
    if (down_part_out !== 8'ha5)
      fail("partially low out-of-range downward indexed part select");

    part_index = 3'bx;
    #1;
    if (part_out !== 8'ha5)
      fail("unknown index must not write any bit");

    signed_part_index = -1;
    #1;
    if (signed_part_out !== 8'ha4)
      fail("partially negative out-of-range indexed part select");

    wide_signed_part_index = -1;
    wide_part_data = 4'b0110;
    #1;
    if (wide_signed_part_out !== 2'b11)
      fail("wide signed negative indexed part select");

    wide_signed_part_index = 0;
    wide_part_data = 4'b0101;
    #1;
    if (wide_signed_part_out !== 2'b01)
      fail("wide signed indexed part select");

    ranged_index = 4'd11;
    ascending_index = 3'd3;
    #1;
    if (ranged_out !== 8'h08 || ascending_out !== 8'h10) begin
      $display("FAILED -- packed range normalization ranged=%h ascending=%h",
               ranged_out, ascending_out);
      $finish;
    end

    for (i = 0; i < 8; i = i + 1) begin
      direct_index = i;
      part_index = i;
      #1;
      expected = '0;
      expected[i] = 1'b1;
      if (direct_out !== expected)
        fail("exhaustive run-time bit index");
      expected = 8'ha5;
      expected[i +: 2] = 2'b10;
      if (part_out !== expected)
        fail("exhaustive upward indexed part select");
      expected = 8'ha4;
      expected[i -: 2] = 2'b10;
      if (down_part_out !== expected)
        fail("exhaustive downward indexed part select");
    end

    for (i = -2; i <= 8; i = i + 1) begin
      signed_part_index = i;
      #1;
      expected = 8'ha5;
      expected[i +: 2] = 2'b01;
      if (signed_part_out !== expected)
        fail("exhaustive signed indexed part select");
    end

    for (i = 8; i <= 15; i = i + 1) begin
      ranged_index = i;
      ascending_index = i - 8;
      #1;
      expected = '0;
      expected[i - 8] = 1'b1;
      if (ranged_out !== expected)
        fail("exhaustive non-zero packed range index");
      expected = '0;
      expected[7 - (i - 8)] = 1'b1;
      if (ascending_out !== expected)
        fail("exhaustive ascending packed range index");
    end

    alert_class = 4'b0110;
    #1;
    if (class_masks !== 8'b0110_1001)
      fail("multi-dimensional packed index A");

    alert_class = 4'b1001;
    #1;
    if (class_masks !== 8'b1001_0110)
      fail("multi-dimensional packed index B");

    alert_class = 4'b1x01;
    #1;
    if (class_masks !== 8'b1001_0010)
      fail("unknown multi-dimensional index must not write any bit");

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

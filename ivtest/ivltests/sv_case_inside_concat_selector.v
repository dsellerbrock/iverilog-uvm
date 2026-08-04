`begin_keywords "1800-2012"

module main;
  logic [1:0] left;
  logic [1:0] right;
  logic [1:0] pair;
  logic [2:0] result;
  logic       repeated_match;

  // Caliptra uses concatenated interface handshakes and concatenated command
  // fields as `case ... inside` selectors. The parser lowering must duplicate
  // the complete selector expression for every membership test.
  always_comb begin
    case ({left, right}) inside
      4'b0001:        result = 3'd1;
      [4'b0100:4'b0111]: result = 3'd2;
      4'b1010:        result = 3'd3;
      default:        result = 3'd0;
    endcase

    case ({2{pair}}) inside
      4'b0101: repeated_match = 1'b1;
      default: repeated_match = 1'b0;
    endcase
  end

  (* ivl_synthesis_off *)
  initial begin
    left = 2'b00;
    right = 2'b01;
    pair = 2'b01;
    #1;
    if (result !== 3'd1 || repeated_match !== 1'b1) begin
      $display("FAILED -- concatenated single/repeated selector");
      $finish;
    end

    left = 2'b01;
    right = 2'b10;
    pair = 2'b10;
    #1;
    if (result !== 3'd2 || repeated_match !== 1'b0) begin
      $display("FAILED -- concatenated range/default selector");
      $finish;
    end

    left = 2'b10;
    right = 2'b10;
    #1;
    if (result !== 3'd3) begin
      $display("FAILED -- concatenated selector update");
      $finish;
    end

    left = 2'b11;
    right = 2'b00;
    #1;
    if (result !== 3'd0) begin
      $display("FAILED -- concatenated selector default");
      $finish;
    end

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

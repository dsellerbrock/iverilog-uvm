`begin_keywords "1800-2012"

module main;
  typedef struct packed {
    logic [3:0] hi;
    logic [3:0] lo;
  } pair_t;

  logic [7:0] source [0:3];
  logic [7:0] result [0:3];
  logic [7:0] clipped [0:3];
  pair_t pairs [0:3];

  always_comb begin
    for (int k = 0; k < 4; k++) begin
      result[k] = source[k] ^ (8'h11 * k);
      result[k][3:0] = source[k][3:0] + k;
      pairs[k].hi = source[k][7:4] + k;
      pairs[k].lo = source[k][3:0] ^ k;
      clipped[k] = source[k];
      clipped[k][((k < 3) ? -3 : 0) +: 2] = 2'b10;
    end
  end

  task automatic fail(input string label);
    $display("FAILED -- %s", label);
    $finish;
  endtask

  (* ivl_synthesis_off *)
  initial begin
    source[0] = 8'h12;
    source[1] = 8'h34;
    source[2] = 8'h56;
    source[3] = 8'h78;
    #1;
    if (result[0] !== 8'h12 || result[1] !== 8'h25 ||
        result[2] !== 8'h78 || result[3] !== 8'h4b) begin
      $display("result=%h %h %h %h", result[0], result[1], result[2], result[3]);
      fail("contextually selected unpacked-array words");
    end
    if (pairs[0] !== 8'h12 || pairs[1] !== 8'h45 ||
        pairs[2] !== 8'h74 || pairs[3] !== 8'hab) begin
      $display("pairs=%h %h %h %h", pairs[0], pairs[1], pairs[2], pairs[3]);
      fail("contextually selected array-of-struct fields");
    end
    if (clipped[0] !== 8'h12 || clipped[1] !== 8'h34 ||
        clipped[2] !== 8'h56 || clipped[3] !== 8'h7a) begin
      $display("clipped=%h %h %h %h",
               clipped[0], clipped[1], clipped[2], clipped[3]);
      fail("contextually out-of-range packed selects");
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

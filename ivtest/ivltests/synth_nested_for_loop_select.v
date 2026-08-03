`begin_keywords "1800-2012"

module main;
  logic [15:0] original [2];
  logic [15:0] mask [2];
  logic [15:0] transformed [2];

  // SHA3 uses nested procedural loops to select an unpacked-array word with
  // the outer index and a packed field with the inner index. Both indices are
  // constants in each synthesized iteration and must remain in scope together.
  always_comb begin
    transformed = original;
    for (int word = 0; word < 2; word++) begin
      for (int nibble = 0; nibble < 4; nibble++) begin
        transformed[word][nibble*4 +: 4] =
          original[word][nibble*4 +: 4] ^ mask[word][nibble*4 +: 4];
      end
    end
  end

  task automatic check(input logic [15:0] original0,
                       input logic [15:0] original1,
                       input logic [15:0] mask0,
                       input logic [15:0] mask1);
    original[0] = original0;
    original[1] = original1;
    mask[0] = mask0;
    mask[1] = mask1;
    #1;
    if (transformed[0] !== (original0 ^ mask0) ||
        transformed[1] !== (original1 ^ mask1)) begin
      $display("FAILED -- transformed=%h/%h expected=%h/%h",
               transformed[0], transformed[1],
               original0 ^ mask0, original1 ^ mask1);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(16'h1234, 16'habcd, 16'h00ff, 16'hf0f0);
    check(16'hdead, 16'hbeef, 16'h5555, 16'haaaa);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords

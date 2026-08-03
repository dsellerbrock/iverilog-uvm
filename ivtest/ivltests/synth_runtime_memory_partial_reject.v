`begin_keywords "1800-2012"

module main;
  logic       clk;
  logic [1:0] addr;
  logic [3:0] data;
  logic [7:0] mem [3];

  // Whole-word run-time selection is supported. Combining it with a packed
  // partial write needs a per-word read/modify/write path and must remain a
  // loud boundary until that distinct lowering is implemented.
  always_ff @(posedge clk)
    mem[addr][3:0] <= data;
endmodule

`end_keywords

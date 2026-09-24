// A runtime index needs its own Preponed sample. Keep this unsupported shape
// visibly warned until both the value and index can be sampled correctly.
module dynamic_index_boundary;
  typedef struct packed { logic [7:0][31:0] sharedkey; } vector_t;
  vector_t vector;
  logic [7:0][31:0] entry;
  logic [2:0] index;
  logic clk;
  check: assert property (@(posedge clk)
    entry[index][0 +: 8] == vector.sharedkey[7-index][0 +: 8]);
endmodule

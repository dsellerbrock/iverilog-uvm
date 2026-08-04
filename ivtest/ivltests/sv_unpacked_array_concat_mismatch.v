// An unpacked array concatenation must provide exactly the destination
// array's element count. Supporting the legal contextual form must not turn
// an underfill into a packed concatenation followed by truncation/padding.
module main;
  typedef enum logic [1:0] { A, B, C, D } item_t;
  wire item_t values [0:3];
  assign values = {A, B};
endmodule

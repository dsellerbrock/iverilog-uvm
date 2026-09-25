module sv_packed_continuous_bit_dag;
  logic root, force_one;
  logic [2:0] tree;
  logic [30:0] wide;
  logic [1:0] cycle;
  logic [2:0] reverse_tree;
  logic [2:0] inputs, independent;

  assign tree[0] = root;
  assign tree[1] = tree[0];
  assign tree[2] = tree[1] | force_one;
  assign wide[0] = 1'b0;
  for (genvar i = 1; i < 31; i++) begin
    assign wide[i] = wide[i-1] | (i == 30);
  end
  assign cycle[0] = cycle[1];
  assign cycle[1] = cycle[0];
  assign reverse_tree[2] = reverse_tree[1] | 1'b1;
  assign reverse_tree[1] = reverse_tree[0];
  assign reverse_tree[0] = 1'b0;
  assign independent[0] = inputs[0];
  assign independent[1] = inputs[1];
  assign independent[2] = inputs[2];

  initial begin
    root = 0;
    force_one = 1;
    inputs = 3'b010;
    #1;
    if (tree !== 3'b100 || reverse_tree !== 3'b100 ||
        wide !== 31'h4000_0000 || independent !== 3'b010 ||
        (^cycle) !== 1'bx) $fatal(1, "initial bit DAG or true cycle");
    root = 1;
    force_one = 0;
    inputs = 3'b101;
    #1;
    if (tree !== 3'b111 || independent !== 3'b101)
      $fatal(1, "changed bit DAG or independent vector");
    root = 1'bx;
    inputs = 3'bx0z;
    #1;
    if (tree !== 3'bxxx || independent !== 3'bx0z)
      $fatal(1, "X/Z propagation");
    root = 1'bz;
    #1;
    if (tree !== 3'bxzz) $fatal(1, "Z propagation");
    $display("PASSED");
    $finish(0);
  end
endmodule

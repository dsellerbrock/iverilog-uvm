interface tree_if;
  logic [2:0][7:4] tree;
endinterface

module legal;
  typedef struct packed { logic [2:0][7:4] tree; } tree_t;
  tree_t s;
  tree_if bus();
  logic [3:0] root, force_one;

  assign s.tree[0] = root;
  assign s.tree[1] = s.tree[0];
  assign s.tree[2] = s.tree[1] | force_one;
  assign bus.tree[0] = root;
  assign bus.tree[1] = bus.tree[0];
  assign bus.tree[2] = bus.tree[1] | force_one;

  initial begin
    root = 4'h1;
    force_one = 4'h8;
    #1;
    if (s.tree !== 12'h911 || bus.tree !== 12'h911)
      $fatal(1, "initial: struct=%h interface=%h", s.tree, bus.tree);
    root = 4'h2;
    force_one = 4'h0;
    #1;
    if (s.tree !== 12'h222 || bus.tree !== 12'h222)
      $fatal(1, "changed: struct=%h interface=%h", s.tree, bus.tree);
    $display("PASSED");
  end
endmodule

interface tree_if;
  logic [2:0][7:4] tree;
endinterface

module overlap;
  typedef struct packed { logic [2:0][7:4] tree; } tree_t;
  tree_t s;
  tree_if bus();
  assign s.tree[0] = 4'h1;
  assign s.tree[1] = s.tree[0];
  assign s.tree[1] = 4'h0;
  assign bus.tree[0] = 4'h1;
  assign bus.tree[1] = bus.tree[0];
endmodule

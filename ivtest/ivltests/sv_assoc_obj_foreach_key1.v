class node_t;
  bit seen[node_t];

  function void add(node_t key);
    seen[key] = 1'b1;
  endfunction

  function bit contains_key(node_t target);
    contains_key = 1'b0;
    foreach (seen[key]) begin
      if (key == target)
        contains_key = 1'b1;
    end
  endfunction
endclass

module test;
  initial begin
    node_t root;
    node_t a;
    node_t b;

    root = new();
    a = new();
    b = new();

    root.add(a);
    root.add(b);

    if (!root.contains_key(a)) begin
      $display("MISS_A");
      $finish(1);
    end

    if (!root.contains_key(b)) begin
      $display("MISS_B");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule

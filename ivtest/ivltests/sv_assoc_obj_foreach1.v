class node_t;
  bit seen[node_t];

  function void add(node_t key);
    seen[key] = 1'b1;
  endfunction

  function int count();
    node_t key;
    count = 0;
    foreach (seen[key])
      count += 1;
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

    if (root.count() != 2) begin
      $display("COUNT_FAIL %0d", root.count());
      $finish(1);
    end

    $display("PASSED");
  end
endmodule

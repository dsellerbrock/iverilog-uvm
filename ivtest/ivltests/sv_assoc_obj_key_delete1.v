class node_t;
  int id;
  function new(int i);
    id = i;
  endfunction
endclass

typedef bit edges_t[node_t];

module test;
  edges_t edges;
  node_t a, b, k;
  int count;

  initial begin
    a = new(1);
    b = new(2);

    edges[a] = 1'b1;
    edges[b] = 1'b1;
    edges.delete(a);

    if (edges.exists(a)) begin
      $display("FAIL: delete(a) left entry behind");
      $finish(1);
    end

    foreach (edges[k]) count += 1;
    if (count != 1 || !edges.exists(b) || edges[b] !== 1'b1) begin
      $display("FAIL: wrong remaining contents count=%0d exists_b=%0d val_b=%0b",
               count, edges.exists(b), edges[b]);
      $finish(1);
    end

    $display("PASS");
  end
endmodule

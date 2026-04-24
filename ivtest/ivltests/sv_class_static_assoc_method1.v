module test;
  class node_t;
    static node_t nodes[string];
    int count;

    function void bump(int inc);
      count += inc;
    endfunction

    static function node_t get_or_create(string key);
      if (!nodes.exists(key))
        nodes[key] = new;
      nodes[key].bump(7);
      return nodes[key];
    endfunction
  endclass

  initial begin
    node_t node_a;
    node_t node_b;

    node_a = node_t::get_or_create("common");
    if (node_a == null) begin
      $display("FAIL: first lookup returned null");
      $finish(1);
    end
    if (node_a.count != 7) begin
      $display("FAIL: first bump count=%0d", node_a.count);
      $finish(1);
    end

    node_b = node_t::get_or_create("common");
    if (node_b != node_a) begin
      $display("FAIL: lookup returned different object");
      $finish(1);
    end
    if (node_b.count != 14) begin
      $display("FAIL: second bump count=%0d", node_b.count);
      $finish(1);
    end

    $display("PASS");
  end
endmodule

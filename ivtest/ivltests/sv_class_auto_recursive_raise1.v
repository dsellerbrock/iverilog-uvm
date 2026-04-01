module test;
  class node;
    int id;
    node parent;

    function new(int n, node p = null);
      id = n;
      parent = p;
    endfunction
  endclass

  class objection;
    int total_count[node];

    function automatic node m_get_parent(node obj);
      if (obj == null)
        return null;
      if (obj.parent != null)
        return obj.parent;
      return null;
    endfunction

    function automatic void m_propagate(node obj, bit raise);
      if (obj != null && obj.parent != null) begin
        obj = m_get_parent(obj);
        if (raise)
          m_raise(obj);
      end
    endfunction

    function automatic void m_raise(node obj);
      int idx;

      if (total_count.exists(obj))
        total_count[obj] += 1;
      else
        total_count[obj] = 1;

      idx = 0;
      while (idx < 1)
        idx++;

      if (obj != null && obj.parent != null)
        m_propagate(obj, 1'b1);
    endfunction
  endclass

  task automatic check(string label, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s got=%0d exp=%0d", label, got, exp);
      $finish(1);
    end
  endtask

  initial begin
    objection o;
    node top;
    node mid;
    node leaf;

    o = new;
    top = new(1, null);
    mid = new(2, top);
    leaf = new(3, mid);

    o.m_raise(leaf);

    check("leaf", o.total_count[leaf], 1);
    check("mid", o.total_count[mid], 1);
    check("top", o.total_count[top], 1);

    $display("PASS");
  end
endmodule

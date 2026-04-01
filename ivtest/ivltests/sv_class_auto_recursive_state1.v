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
    bit failed;

    function automatic node m_get_parent(node obj);
      if (obj == null)
        return null;
      if (obj.parent != null)
        return obj.parent;
      return null;
    endfunction

    function automatic void m_propagate(node obj, bit raise);
      int expect_id;
      bit expect_raise;

      if (obj != null && obj.parent != null) begin
        expect_id = obj.parent.id;
        expect_raise = raise;
        obj = m_get_parent(obj);
        if (raise)
          m_raise(obj);
        else
          m_drop(obj);

        if (obj == null || obj.id != expect_id || raise !== expect_raise) begin
          $display("FAIL propagate-state expected_obj=%0d got_obj=%0d expected_raise=%b got_raise=%b",
                   expect_id, obj == null ? -1 : obj.id, expect_raise, raise);
          failed = 1'b1;
        end
      end
    endfunction

    function automatic void m_raise(node obj);
      int expect_id;

      expect_id = obj == null ? -1 : obj.id;
      if (total_count.exists(obj))
        total_count[obj] += 1;
      else
        total_count[obj] = 1;

      if (obj != null && obj.parent != null)
        m_propagate(obj, 1'b1);

      if (obj == null || obj.id != expect_id) begin
        $display("FAIL raise-state expected_obj=%0d got_obj=%0d",
                 expect_id, obj == null ? -1 : obj.id);
        failed = 1'b1;
      end
    endfunction

    function automatic void m_drop(node obj);
      int expect_id;

      expect_id = obj == null ? -1 : obj.id;
      if (total_count.exists(obj))
        total_count[obj] -= 1;
      else
        total_count[obj] = -1;

      if (total_count[obj] != 0) begin
        if (obj != null && obj.parent != null)
          m_propagate(obj, 1'b0);
      end

      if (obj == null || obj.id != expect_id) begin
        $display("FAIL drop-state expected_obj=%0d got_obj=%0d",
                 expect_id, obj == null ? -1 : obj.id);
        failed = 1'b1;
      end
    endfunction
  endclass

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
    o.m_drop(leaf);

    if (o.total_count.exists(leaf) && o.total_count[leaf] != 0) begin
      $display("FAIL final leaf=%0d", o.total_count[leaf]);
      o.failed = 1'b1;
    end
    if (o.total_count.exists(mid) && o.total_count[mid] != 0) begin
      $display("FAIL final mid=%0d", o.total_count[mid]);
      o.failed = 1'b1;
    end
    if (o.total_count.exists(top) && o.total_count[top] != 0) begin
      $display("FAIL final top=%0d", o.total_count[top]);
      o.failed = 1'b1;
    end

    if (o.failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule

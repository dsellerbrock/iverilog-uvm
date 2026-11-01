class issue2153_leaf;
  rand bit [3:0] value;
endclass

class issue2153_holder;
  rand issue2153_leaf items[$];
  constraint size_c { items.size == 2; }
endclass

module test;
  issue2153_holder h;
  bit ok;

  initial begin
    h = new;
    ok = h.randomize();
    if (ok != 1 || h.items.size() != 2
        || h.items[0] != null || h.items[1] != null)
      $fatal(1, "queue size randomize failed: ok=%0d size=%0d nulls=%0d%0d",
             ok, h.items.size(), h.items[0] == null, h.items[1] == null);
    $display("ISSUE2153_CLASS_HANDLE_QUEUE_SIZE_PASS");
  end
endmodule

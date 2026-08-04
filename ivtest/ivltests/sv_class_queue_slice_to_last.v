// IEEE 1800-2017 7.10.1: queue slices retain queue value semantics when
// the queue is reached through an instance, nested, or static class property.
class queue_holder;
  int q[$];
endclass

class outer_holder;
  queue_holder inner;
  function new;
    inner = new;
  endfunction
endclass

module main;
  bit failed;
  queue_holder h;
  outer_holder outer;
  int r[$];
  int lo;

  task check(string label, bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  initial begin
    h = new;
    outer = new;
    h.q = {10, 20, 30, 40};
    outer.inner.q = {5, 6, 7};
    lo = 1;
    r = h.q[lo:$];
    check("instance property", r.size() == 3 &&
          r[0] == 20 && r[1] == 30 && r[2] == 40);

    r = outer.inner.q[1:$];
    check("nested property", r.size() == 2 && r[0] == 6 && r[1] == 7);

    r[0] = -1;
    check("property slice copy", h.q[1] == 20);

    if (failed)
      $finish(1);
    else begin
      $display("PASSED");
      $finish(0);
    end
  end
endmodule

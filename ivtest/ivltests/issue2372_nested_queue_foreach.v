// Issue #2372: a parent constraint over a nested rand object's queue is
// solved together with that object's own constraints (IEEE 1800-2023
// 18.5.8): a foreach over the nested queue's elements, and a constant
// element of it, are representable and satisfiable.
module top;
  class child;
    rand bit [7:0] q[$];
    constraint c { q.size() inside {[1:4]}; foreach (q[i]) q[i] < 50; }
  endclass

  class parent;
    rand child ch;
    constraint p { foreach (ch.q[i]) ch.q[i] > 10; }
    function new(); ch = new; endfunction
  endclass

  class fixed_child;
    rand bit [7:0] q[$];
  endclass

  // The nested queue's size is not constrained: it keeps its size.
  class keeps_size;
    rand fixed_child ch;
    constraint p { foreach (ch.q[i]) ch.q[i] == 8'(i + 3); }
    function new(); ch = new; ch.q = '{0, 0, 0}; endfunction
  endclass

  // The parent sets the nested queue's size and ties its elements to a
  // variable of its own.
  class ties_parent;
    rand fixed_child ch;
    rand bit [7:0] x;
    constraint c { ch.q.size() == 3; foreach (ch.q[i]) ch.q[i] == x + i;
                   x < 8'd100; }
    function new(); ch = new; endfunction
  endclass

  class first_elem;
    rand child ch;
    constraint p { ch.q[0] > 40; }
    function new(); ch = new; endfunction
  endclass

  parent p = new;
  keeps_size k = new;
  ties_parent t = new;
  first_elem f = new;
  int failures = 0;

  initial begin
    repeat (20) begin
      if (!p.randomize()) failures++;
      if (p.ch.q.size() < 1 || p.ch.q.size() > 4) failures++;
      foreach (p.ch.q[i]) if (p.ch.q[i] <= 10 || p.ch.q[i] >= 50) failures++;
    end
    if (!k.randomize()) failures++;
    if (k.ch.q.size() != 3 || k.ch.q[0] != 3 || k.ch.q[1] != 4 || k.ch.q[2] != 5)
      failures++;
    repeat (10) begin
      if (!t.randomize()) failures++;
      if (t.ch.q.size() != 3 || t.ch.q[0] != t.x || t.ch.q[1] != t.x + 1
          || t.ch.q[2] != t.x + 2 || t.x >= 100) failures++;
    end
    repeat (10) begin
      if (!f.randomize()) failures++;
      if (f.ch.q.size() < 1 || f.ch.q[0] <= 40 || f.ch.q[0] >= 50) failures++;
    end
    if (failures == 0) $display("PASSED");
    else $display("FAILED: %0d", failures);
  end
endmodule

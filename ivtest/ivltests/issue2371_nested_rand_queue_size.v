// IEEE 1800-2017 18.4, 18.5.8 / IEEE 1800-2023 18.4, 18.5.9:
// a parent constraint can solve the size of a rand queue in a rand child.
class issue2371_child;
  rand bit [7:0] q[$];
  constraint q_values { foreach (q[i]) q[i] < 50; }
endclass

class issue2371_parent;
  rand issue2371_child ch;
  rand int n;
  constraint parent_size { n inside {[2:3]}; ch.q.size() == n; }
  function new(); ch = new; endfunction
endclass

module test;
  issue2371_parent p;
  initial begin
    p = new;
    p.srandom(2371);
    repeat (20) begin
      if (!p.randomize()) $fatal(1, "parent/child queue solve failed");
      if (p.n < 2 || p.n > 3 || p.ch.q.size() != p.n)
        $fatal(1, "nested queue size %0d does not match n=%0d",
               p.ch.q.size(), p.n);
      foreach (p.ch.q[i])
        if (p.ch.q[i] >= 50)
          $fatal(1, "child queue element %0d violated its constraint", i);
    end
    $display("PASSED");
  end
endmodule

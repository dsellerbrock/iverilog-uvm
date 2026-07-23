// Check the "inside" operator with queue/darray class properties as the
// container operand: obj.q, deep chains, this.q inside class methods,
// empty/null containers, and mixed value+container item lists. The
// container membership must be evaluated against the live container,
// not degrade to an equality compare on the handle.
module main;
  class C;
    int q[$];
    int d[];
    function bit has(int v); return v inside {q}; endfunction
  endclass
  class H;
    C c;
    function new(); c = new(); endfunction
  endclass

  bit failed = 0;
  task check(string label, bit got, bit exp);
    if (got !== exp) begin
       $display("FAILED -- %0s: got %b, expected %b", label, got, exp);
       failed = 1;
    end
  endtask

  initial begin
    automatic C c = new;
    automatic C nul = new;
    automatic H h = new;
    c.q.push_back(3); c.q.push_back(7);
    c.d = new[2]; c.d[0] = 10; c.d[1] = 20;
    h.c.q.push_back(42);

    check("queue prop hit", 7 inside {c.q}, 1);
    check("queue prop miss", 5 inside {c.q}, 0);
    check("darray prop hit", 20 inside {c.d}, 1);
    check("darray prop miss", 5 inside {c.d}, 0);
    check("deep chain hit", 42 inside {h.c.q}, 1);
    check("deep chain miss", 1 inside {h.c.q}, 0);
    check("empty queue", 1 inside {nul.q}, 0);
    check("null darray", 1 inside {nul.d}, 0);
    check("mixed scalar hit", 99 inside {c.q, 99}, 1);
    check("mixed container hit", 7 inside {c.q, 99}, 1);
    check("mixed miss", 8 inside {c.q, 99}, 0);
    check("this.q hit", c.has(7), 1);
    check("this.q miss", c.has(8), 0);

    if (!failed) $display("PASSED");
  end
endmodule

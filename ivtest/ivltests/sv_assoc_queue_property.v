// Assoc-of-queue class properties: c.aq[key].push_back(v) used to drop
// the mutation (the assoc element was read with a plain load that
// returns nil for a missing key — now a get-or-create load vivifies an
// empty queue of the right element kind); pops/methods on indexed
// container properties elaborated to a constant-0 stub via a width-query
// give-up; deep-chain double-index reads (h.c.iq[k][i]) dropped the
// trailing index and returned the whole inner queue.
module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  class C;
    int iq[int][$];
    int aq[string][$];
    string sq[string][$];
  endclass
  class H;
    C c;
    function new(); c = new(); endfunction
  endclass

  initial begin
    automatic C c = new;
    automatic H h = new;
    automatic int v;

    // string-keyed vivify + push
    c.aq["k"].push_back(5);
    c.aq["k"].push_back(6);
    check("str key", c.aq["k"].size() == 2 && c.aq["k"][1] == 6);
    check("str key num", c.aq.num() == 1);

    // int keys, negative keys
    c.iq[7].push_back(70);
    c.iq[7].push_back(71);
    c.iq[-2].push_back(20);
    check("int key", c.iq[7].size() == 2 && c.iq[7][1] == 71
          && c.iq[-2][0] == 20 && c.iq.num() == 2);

    // pop through the property assoc element (was a silent constant 0)
    v = c.iq[7].pop_front();
    check("pop front", v == 70 && c.iq[7].size() == 1);

    // string-element queues store as strings, not vec4
    c.sq["names"].push_back("alpha");
    c.sq["names"].push_back("beta");
    check("str elems", c.sq["names"].size() == 2
          && c.sq["names"][1] == "beta");

    // deep chain: push, size, and double-index read
    h.c.iq[3].push_back(33);
    check("deep chain", h.c.iq[3].size() == 1 && h.c.iq[3][0] == 33);

    // key delete and re-push into an existing element (no re-vivify)
    c.iq.delete(-2);
    check("delete key", c.iq.num() == 1 && !c.iq.exists(-2));
    c.iq[7].push_back(72);
    check("no clobber", c.iq[7].size() == 2 && c.iq[7][0] == 71
          && c.iq[7][1] == 72);

    if (!failed) $display("PASSED");
  end
endmodule

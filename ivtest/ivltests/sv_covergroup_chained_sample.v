// Check covergroup method calls chained through class properties:
// obj.cg.sample() from module scope, deep chains (h.c.cg.sample()),
// iff guards through chains, and sampling another object's covergroup
// from inside an unrelated class method (the coverpoint values must
// come from the covergroup's parent object, not the caller's "this").
module main;
  class Cov;
    int val;
    bit en;
    covergroup cg;
      cp: coverpoint val iff (en) { bins lo = {[0:3]}; bins hi = {[4:7]}; }
    endgroup
    function new(); cg = new(); en = 1; endfunction
  endclass

  class Holder;
    Cov c;
    function new(); c = new(); endfunction
  endclass

  class Alien;
    int val; // decoy property; must never be sampled
    function void poke(Cov t);
      t.val = 6;
      t.cg.sample();
    endfunction
  endclass

  bit failed = 0;

  task check(string label, real got, real exp);
    if (got != exp) begin
       $display("FAILED -- %0s: got %f, expected %f", label, got, exp);
       failed = 1;
    end
  endtask

  initial begin
    automatic Cov g = new;
    automatic Holder h = new;
    automatic Alien a = new;
    automatic Cov q = new;

    // module-scope chained sample
    g.val = 2; g.cg.sample();
    g.val = 6; g.cg.sample();
    check("chained", g.cg.get_inst_coverage(), 100.0);

    // deep chain through two properties
    h.c.val = 2; h.c.cg.sample();
    check("deep-chain", h.c.cg.get_inst_coverage(), 50.0);

    // iff guard honored through the chain
    q.en = 0;
    q.val = 2; q.cg.sample();
    check("guard-off", q.cg.get_inst_coverage(), 0.0);
    q.en = 1;
    q.cg.sample();
    check("guard-on", q.cg.get_inst_coverage(), 50.0);

    // sample another object's covergroup from an unrelated class:
    // values must come from t (the parent), not the caller.
    begin
      automatic Cov t = new;
      a.val = 2; // decoy value in the lo bin
      t.val = 0;
      a.poke(t); // sets t.val=6 -> hi bin only
      check("cross-object", t.cg.get_inst_coverage(), 50.0);
    end

    if (!failed) $display("PASSED");
  end
endmodule

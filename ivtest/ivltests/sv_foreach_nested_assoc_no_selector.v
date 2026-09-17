// Companion to sv_foreach_selected_prefix_assoc_fail.v: a foreach over
// a class property that is itself an associative array, reached
// through a DOTTED, INDEXED prefix whose OWN index is an ordinary loop
// variable from an ENCLOSING foreach (not a fixed selector on the
// associative target itself), must keep working correctly -- exactly
// the shape UVM's own uvm_phase.svh relies on (`foreach (successors[s])
// ... foreach (successors[s].m_predecessors[pred]) ...', where `s' is
// the outer foreach's loop variable and `m_predecessors' -- the actual
// foreach target -- carries no selector of its own). A prior version
// of the DD-040 fix in this session misclassified this shape as a
// selector-prefixed target (checking every path component for an
// index instead of just the final one) and refused it, which broke
// 100% of UVM compilation since uvm_phase.svh is a mandatory
// dependency of every UVM test. This must never regress silently: a
// real runtime check, not just a compile check, since a wrong (but
// compiling) fix could still misassociate `s' across iterations.
module main;
  class node_c;
    int m_predecessors[int];
  endclass

  node_c successors[int];
  int fails;

  initial begin
    successors[0] = new;
    successors[1] = new;
    successors[0].m_predecessors[10] = 1;
    successors[0].m_predecessors[11] = 1;
    successors[1].m_predecessors[20] = 1;

    foreach (successors[s]) begin
      int seen;
      seen = 0;
      foreach (successors[s].m_predecessors[pred]) begin
        seen++;
        if (s == 0 && pred != 10 && pred != 11) fails++;
        if (s == 1 && pred != 20) fails++;
      end
      if (s == 0 && seen != 2) fails++;
      if (s == 1 && seen != 1) fails++;
    end

    if (fails == 0) $display("PASSED");
    else $display("FAILED, fails=%0d", fails);
    $finish;
  end
endmodule

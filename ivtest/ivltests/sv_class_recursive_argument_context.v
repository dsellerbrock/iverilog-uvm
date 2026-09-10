// IEEE 1800-2017/2023 8.6 and 13.5.1: nested calls while preparing
// recursive arguments must keep reading the caller's automatic variables.
module sv_class_recursive_argument_context;
  class node;
    int value;
    node child;
    function new(int v); value = v; endfunction
    function node get_child();
      return child;
    endfunction
    function node identity(); return this; endfunction
  endclass
  class walker;
    int visits;
    virtual function void first(node comp, node phase, int state,
                                string label, real amount);
      if (phase == null || phase.value != 37 || state != 19 ||
          label != "caller" || amount != 2.5)
        $fatal(1, "first argument nested call lost caller inputs");
      visits++;
      if (comp.child != null) begin
        first(comp.get_child(), phase, state, label, amount);
      end
    endfunction
    function void middle(node comp, node phase, int state);
      if (phase == null || phase.value != 37 || state != 19)
        $fatal(1, "middle argument nested call lost caller inputs");
      visits++;
      if (comp.child != null) middle(comp.child, phase.identity(), state);
    endfunction
    function int same_scope(int depth, int value);
      if (depth == 0) return value;
      return same_scope(same_scope(0, depth-1), value+1);
    endfunction
  endclass
  initial begin
    node root, leaf, phase;
    walker w;
    root = new(1); leaf = new(2); phase = new(37); w = new;
    root.child = leaf;
    w.first(root, phase, 19, "caller", 2.5);
    w.middle(root, phase, 19);
    if (w.visits != 4) $fatal(1, "missing traversal");
    if (w.same_scope(3, 37) != 40) $fatal(1, "same-scope nested call");
    $display("PASSED");
  end
endmodule

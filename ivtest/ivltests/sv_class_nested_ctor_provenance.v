/*
 * IEEE 1800-2017 8.7, 8.10: each `new' invocation constructs a DISTINCT
 * object, and a constructor invoked from inside another constructor of the
 * same class must not alias its caller's object or overwrite its properties.
 *
 * An object store resolved the destination signal's post-store value through
 * the thread's READ context while the store itself had gone through its
 * WRITE context. Inside a nested constructor those are different frames, so
 * peeking a class-handle `this' returned the CALLER's object and redirected
 * the destination's alias provenance at it. The nested `new' then aliased its
 * own parent -- `root.child === root' -- and the inner property writes landed
 * on the outer object.
 *
 * Beyond corrupting values this could not terminate: a constructor whose
 * recursion is bounded by an argument (the classic UVM phase-graph shape,
 * where the child is built with a different type and a non-null parent) saw
 * the child observe the PARENT's arguments, so the guard that stops the
 * recursion never became false and the run spun forever.
 */
module sv_class_nested_ctor_provenance;

  typedef class node_t;

  class node_t;
    string  nm;
    int     depth;
    node_t  child;
    node_t  parent;

    function new(string name = "root", int d = 0, node_t up = null);
      nm     = name;
      depth  = d;
      parent = up;
      // Bounded by the argument, exactly like a phase graph terminal node.
      if (up == null)
        child = new({name, "_end"}, d + 1, this);
    endfunction
  endclass

  node_t root;
  int    fails = 0;

  task automatic ck_str(string tag, string got, string want);
    if (got != want) begin
      fails += 1;
      $display("FAILED: %s got '%s' want '%s'", tag, got, want);
    end
  endtask

  task automatic ck_int(string tag, int got, int want);
    if (got != want) begin
      fails += 1;
      $display("FAILED: %s got %0d want %0d", tag, got, want);
    end
  endtask

  initial begin
    root = new("common", 0, null);

    // The nested new must have produced a separate object.
    if (root.child == root) begin
      fails += 1;
      $display("FAILED: nested new aliased its own caller's object");
    end
    if (root.child == null) begin
      fails += 1;
      $display("FAILED: nested new produced no child");
    end

    // The outer frame's properties must survive the inner invocation.
    ck_str("root.nm",    root.nm,    "common");
    ck_int("root.depth", root.depth, 0);
    if (root.parent != null) begin
      fails += 1;
      $display("FAILED: root.parent was overwritten by the nested call");
    end

    // The inner invocation's own actuals must reach its own object.
    ck_str("child.nm",    root.child.nm,    "common_end");
    ck_int("child.depth", root.child.depth, 1);
    if (root.child.parent != root) begin
      fails += 1;
      $display("FAILED: child.parent is not the constructing object");
    end

    // The recursion terminated: the child built no grandchild.
    if (root.child.child != null) begin
      fails += 1;
      $display("FAILED: bounded constructor recursion did not terminate");
    end

    if (fails == 0)
      $display("PASSED");
  end

endmodule

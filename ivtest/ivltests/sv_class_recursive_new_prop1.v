module test;

  class phase_t;
    string name;
    int kind;
    phase_t parent;
    phase_t m_end_node;

    function new(string name = "phase", int kind = 0, phase_t parent = null);
      this.name = name;
      this.kind = kind;
      this.parent = parent;

      if (parent == null && kind == 0)
        m_end_node = new({name, "_end"}, 1, this);
    endfunction
  endclass

  initial begin
    phase_t root;

    root = new("common", 0, null);

    if (root.m_end_node == null) begin
      $display("FAILED: missing recursive child");
      $finish(1);
    end

    if (root.m_end_node.parent != root) begin
      $display("FAILED: child parent corrupted");
      $finish(1);
    end

    if (root.m_end_node.name != "common_end") begin
      $display("FAILED: child name got '%s'", root.m_end_node.name);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule

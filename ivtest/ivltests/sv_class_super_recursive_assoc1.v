module test;
  localparam int KIND_TERMINAL = 1;
  localparam int KIND_DOMAIN = 2;

  class base_t;
    string name;
    int kind;
    base_t parent;
    base_t m_end_node;
    int successors[base_t];
    int predecessors[base_t];

    function new(string name = "base", int kind = 0, base_t parent = null);
      this.name = name;
      this.kind = kind;
      this.parent = parent;
      if (parent == null && kind == KIND_DOMAIN) begin
        m_end_node = new({name, "_end"}, KIND_TERMINAL, this);
        this.successors[m_end_node] = 1;
        m_end_node.predecessors[this] = 1;
      end
    endfunction
  endclass

  class derived_t extends base_t;
    static derived_t registry[string];

    static function bit has_name(string name);
      return registry.exists(name);
    endfunction

    function new(string name = "derived");
      super.new(name, KIND_DOMAIN, null);
      registry[name] = this;
    endfunction
  endclass

  initial begin
    derived_t root;
    root = new("common");

    if (root.m_end_node == null) begin
      $display("FAILED: missing recursive child");
      $finish(1);
    end

    if (root.m_end_node.parent != root) begin
      $display("FAILED: child parent corrupted");
      $finish(1);
    end

    if (!root.successors.exists(root.m_end_node)) begin
      $display("FAILED: missing successor edge");
      $finish(1);
    end

    if (!root.m_end_node.predecessors.exists(root)) begin
      $display("FAILED: missing predecessor edge");
      $finish(1);
    end

    if (!derived_t::has_name("common")) begin
      $display("FAILED: registry lookup missing root");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule

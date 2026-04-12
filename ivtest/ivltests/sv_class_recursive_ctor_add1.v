module test;
  typedef enum int {
    PH_END = 0,
    PH_DOMAIN = 4
  } phase_type_t;

  class object_t;
    string m_name;

    function new(string name = "obj");
      m_name = name;
    endfunction
  endclass

  class phase_t extends object_t;
    phase_type_t m_phase_type;
    phase_t m_end_node;
    phase_t m_parent;
    phase_t m_children[$];

    function void add(phase_t child);
      phase_t tmp;
      tmp = child;
      if (tmp != null)
        m_children.push_back(tmp);
    endfunction

    function new(string name = "phase",
                 phase_type_t phase_type = PH_END,
                 phase_t parent = null);
      super.new(name);
      m_phase_type = phase_type;
      m_parent = parent;

      if (phase_type == PH_DOMAIN) begin
        phase_t tmp;
        tmp = new({name, "_end"}, PH_END, this);
        m_end_node = tmp;
        add(tmp);
      end
    endfunction
  endclass

  class domain_t extends phase_t;
    function new(string name = "domain");
      super.new(name, PH_DOMAIN, null);
    endfunction
  endclass

  initial begin
    domain_t d;

    d = new("d");

    if (d.m_phase_type != PH_DOMAIN) begin
      $display("FAIL phase_type=%0d", d.m_phase_type);
      $finish(1);
    end

    if (d.m_end_node == null) begin
      $display("FAIL end_node null");
      $finish(1);
    end

    if (d.m_end_node.m_phase_type != PH_END) begin
      $display("FAIL end_phase=%0d", d.m_end_node.m_phase_type);
      $finish(1);
    end

    if (d.m_children.size() != 1) begin
      $display("FAIL children=%0d", d.m_children.size());
      $finish(1);
    end

    $display("PASS");
  end
endmodule

module test;
  typedef enum int { PH_NODE=1, PH_IMP=2, PH_DOMAIN=4 } phase_type_t;
  typedef class phase_base;
  typedef class domain_t;

  class phase_base;
    typedef bit edges_t[phase_base];
    string m_name;
    phase_type_t m_phase_type;
    phase_base m_parent;
    phase_base m_imp;
    edges_t m_successors;

    function new(string name="phase", phase_type_t phase_type=PH_NODE, phase_base parent=null);
      m_name = name;
      m_phase_type = phase_type;
      m_parent = parent;
    endfunction

    function phase_base get_imp(); return m_imp; endfunction
    function phase_base get_schedule(bit hier=0); return null; endfunction
    function domain_t get_domain();
      phase_base phase;
      phase = this;
      while (phase != null && phase.m_phase_type != PH_DOMAIN)
        phase = phase.m_parent;
      if (phase == null)
        return null;
      if (!$cast(get_domain, phase))
        return null;
    endfunction

    function phase_base m_find_predecessor(phase_base phase, bit stay_in_scope=1, phase_base orig_phase=null);
      return null;
    endfunction

    function phase_base m_find_successor(phase_base phase, bit stay_in_scope=1, phase_base orig_phase=null);
      phase_base found;
      if (phase == null)
        return null;
      if (phase == m_imp || phase == this)
        return this;
      foreach (m_successors[succ]) begin
        phase_base orig;
        orig = (orig_phase == null) ? this : orig_phase;
        if (!stay_in_scope || (succ.get_schedule() == orig.get_schedule()) || (succ.get_domain() == orig.get_domain())) begin
          found = succ.m_find_successor(phase, stay_in_scope, orig);
          if (found != null)
            return found;
        end
      end
      return null;
    endfunction

    function phase_base find(phase_base phase, bit stay_in_scope=1);
      if (phase == m_imp || phase == this)
        return phase;
      find = m_find_predecessor(phase, stay_in_scope, this);
      if (find == null)
        find = m_find_successor(phase, stay_in_scope, this);
    endfunction
  endclass

  class domain_t extends phase_base;
    function new(string name="common");
      super.new(name, PH_DOMAIN, null);
    endfunction
    function void add_imp(phase_base phase);
      phase_base node;
      node = new(phase.m_name, PH_NODE, this);
      node.m_imp = phase;
      m_successors[node] = 1;
    endfunction
  endclass

  class imp_t extends phase_base;
    function new(string name="build");
      super.new(name, PH_IMP, null);
    endfunction
  endclass

  initial begin
    domain_t common;
    imp_t build;
    phase_base found;
    common = new("common");
    build = new("build");
    common.add_imp(build);
    found = common.find(build);
    if (found == null) begin
      $display("FAIL found null");
      $finish(1);
    end
    if (found.get_imp() != build) begin
      $display("FAIL imp mismatch");
      $finish(1);
    end
    $display("PASS");
  end
endmodule

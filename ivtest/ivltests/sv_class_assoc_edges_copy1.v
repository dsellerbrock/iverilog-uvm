module test;
  typedef enum int {
    PH_SCHEDULE = 0,
    PH_NODE = 1,
    PH_IMP = 2
  } phase_type_t;

  typedef class phase_t;

  class phase_t;
    typedef bit edges_t[phase_t];

    string m_name;
    phase_type_t m_phase_type;
    phase_t m_parent;
    phase_t m_imp;
    edges_t m_successors;

    function new(string name = "phase",
                 phase_type_t phase_type = PH_SCHEDULE,
                 phase_t parent = null);
      m_name = name;
      m_phase_type = phase_type;
      m_parent = parent;
    endfunction

    function phase_type_t get_phase_type();
      return m_phase_type;
    endfunction

    function phase_t get_parent();
      return m_parent;
    endfunction

    function phase_t get_imp();
      return m_imp;
    endfunction

    function void add_imp(phase_t phase);
      phase_t node;
      node = new(phase.m_name, PH_NODE, this);
      node.m_imp = phase;
      m_successors[node] = 1;
    endfunction

    function void get_successors(ref edges_t successors);
      foreach (m_successors[p]) begin
        successors[p] = 1;
      end
    endfunction
  endclass

  initial begin
    phase_t schedule;
    phase_t imp;
    phase_t succ_q[$];
    phase_t::edges_t edges;

    schedule = new("common", PH_SCHEDULE);
    imp = new("build", PH_IMP);
    schedule.add_imp(imp);
    schedule.get_successors(edges);

    foreach (edges[succ]) begin
      succ_q.push_back(succ);
    end

    if (succ_q.size() != 1) begin
      $display("FAILED -- succ_q.size=%0d expected 1", succ_q.size());
      $finish(1);
    end

    if (succ_q[0].get_phase_type() != PH_NODE) begin
      $display("FAILED -- successor phase_type=%0d expected %0d",
               succ_q[0].get_phase_type(), PH_NODE);
      $finish(1);
    end

    if (succ_q[0].get_parent() != schedule) begin
      $display("FAILED -- successor parent mismatch");
      $finish(1);
    end

    if (succ_q[0].get_imp() != imp) begin
      $display("FAILED -- successor imp mismatch");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule

module test;
  typedef enum int {
    PH_SCHEDULE = 0,
    PH_NODE = 1,
    PH_IMP = 2
  } phase_type_t;

  class phase_t;
    string m_name;
    phase_type_t m_phase_type;
    phase_t m_parent;
    phase_t m_imp;

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
  endclass

  initial begin
    phase_t imp;
    phase_t parent;
    phase_t node;

    imp = new("build", PH_IMP);
    parent = new("common", PH_SCHEDULE);
    node = new(imp.m_name, PH_NODE, parent);
    node.m_imp = imp;

    if (node.get_phase_type() != PH_NODE) begin
      $display("FAILED -- node phase_type=%0d expected %0d",
               node.get_phase_type(), PH_NODE);
      $finish(1);
    end

    if (node.get_parent() != parent) begin
      $display("FAILED -- node parent mismatch");
      $finish(1);
    end

    if (node.get_imp() != imp) begin
      $display("FAILED -- node imp mismatch");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule

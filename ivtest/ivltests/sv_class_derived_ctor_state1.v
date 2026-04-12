module test;
  typedef enum int {
    PH_END = 0,
    PH_DOMAIN = 1
  } phase_type_t;

  class phase_t;
    string m_name;
    phase_type_t m_phase_type;
    phase_t m_end_node;

    function new(string name = "phase",
                 phase_type_t phase_type = PH_END);
      m_name = name;
      m_phase_type = phase_type;
      if (phase_type != PH_END)
        m_end_node = new({name, "_end"}, PH_END);
    endfunction
  endclass

  class domain_t extends phase_t;
    function new(string name = "domain");
      super.new(name, PH_DOMAIN);
    endfunction
  endclass

  initial begin
    domain_t d;
    d = new("d");

    if (d.m_phase_type != PH_DOMAIN) begin
      $display("FAILED -- phase_type=%0d expected %0d",
               d.m_phase_type, PH_DOMAIN);
      $finish(1);
    end

    if (d.m_end_node == null) begin
      $display("FAILED -- end node is null");
      $finish(1);
    end

    if (d.m_end_node.m_phase_type != PH_END) begin
      $display("FAILED -- end phase_type=%0d expected %0d",
               d.m_end_node.m_phase_type, PH_END);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule

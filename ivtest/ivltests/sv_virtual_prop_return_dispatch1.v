module test;
  typedef class phase_base;
  typedef class comp_base;

  class phase_base;
    virtual function void execute(comp_base c, phase_base ph);
      $display("FAILED -- base execute dispatched");
      $finish(1);
    endfunction

    virtual function void exec_func(comp_base c, phase_base ph);
      $display("FAILED -- base exec_func dispatched");
      $finish(1);
    endfunction
  endclass

  class comp_base;
    virtual function void build_phase(phase_base ph);
      $display("FAILED -- base build_phase dispatched");
      $finish(1);
    endfunction
  endclass

  class worker_t extends comp_base;
    int hits;

    function void build_phase(phase_base ph);
      hits += 1;
    endfunction
  endclass

  class function_phase_t extends phase_base;
    virtual function void execute(comp_base c, phase_base ph);
      exec_func(c, ph);
    endfunction
  endclass

  class build_phase_t extends function_phase_t;
    function void exec_func(comp_base c, phase_base ph);
      c.build_phase(ph);
    endfunction
  endclass

  class holder_t;
    phase_base m_imp;

    function phase_base get_imp();
      return m_imp;
    endfunction
  endclass

  class hopper_t;
    function void execute_on(phase_base imp, comp_base c, phase_base ph);
      imp.execute(c, ph);
    endfunction
  endclass

  initial begin
    holder_t holder;
    hopper_t hopper;
    build_phase_t build_imp;
    worker_t worker;
    phase_base imp;

    holder = new;
    hopper = new;
    build_imp = new;
    worker = new;

    holder.m_imp = build_imp;
    imp = holder.get_imp();
    hopper.execute_on(imp, worker, imp);

    if (worker.hits !== 1) begin
      $display("FAILED -- worker.hits=%0d, expected 1", worker.hits);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule

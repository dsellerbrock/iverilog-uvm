module test;
  class phase_base;
  endclass

  class comp_base;
    virtual function void build_phase(phase_base ph);
      $display("FAILED -- base build_phase dispatched");
      $finish(1);
    endfunction
  endclass

  class test_comp extends comp_base;
    int hits;

    virtual function void build_phase(phase_base ph);
      hits += 1;
    endfunction
  endclass

  class phase_root;
    virtual function void exec_func(comp_base c, phase_base ph);
    endfunction

    function void execute(comp_base c, phase_base ph);
      exec_func(c, ph);
    endfunction
  endclass

  class build_phase_t extends phase_root;
    virtual function void exec_func(comp_base c, phase_base ph);
      c.build_phase(ph);
    endfunction
  endclass

  initial begin
    build_phase_t p;
    comp_base c;
    test_comp d;
    phase_base ph;

    p = new;
    d = new;
    c = d;
    ph = new;

    p.execute(c, ph);

    if (d.hits !== 1) begin
      $display("FAILED -- d.hits=%0d, expected 1", d.hits);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule

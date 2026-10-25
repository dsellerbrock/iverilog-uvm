class C;
  int x;
  covergroup cg;
    coverpoint this.x { bins expected_value = {2}; }
  endgroup
  function new();
    x = 2;
    cg = new;
  endfunction
endclass

module sv_covergroup_this_instance;
  C c;
  initial begin
    c = new;
    c.cg.sample();
    if (c.cg.get_coverage() != 100.0)
      $fatal(1, "FAIL this.x in embedded covergroup sampled wrong value");
    $display("PASSED");
  end
endmodule

module test;
  covergroup cg(logic [1:0] enabled) with function sample(int v);
    type_option.merge_instances = 1;
    option.get_inst_coverage = enabled;
    cp: coverpoint v { bins b[] = {[0:1]}; }
  endgroup
  covergroup compound(logic [1:0] enabled) with function sample(int v);
    type_option.merge_instances = 1;
    option.get_inst_coverage = enabled & 2'b01;
    cp: coverpoint v { bins b[] = {[0:1]}; }
  endgroup
  cg a,b;
  compound c,d;
  int calls;
  function automatic logic [1:0] next_value();
    calls++;
    return 2'bx1;
  endfunction
  initial begin
    a=new(next_value()); b=new(2'b00);
    c=new(2'bz1); d=new(2'b00);
    a.sample(0); b.sample(1); c.sample(0); d.sample(1);
    if (calls != 1) $fatal(1,"constructor actual evaluated more than once");
    if (a.option.get_inst_coverage !== 1'b1 || a.get_inst_coverage()!=50.0)
      $fatal(1,"four-state bit assignment");
    if (c.option.get_inst_coverage !== 1'b1 || c.get_inst_coverage()!=50.0)
      $fatal(1,"four-state expression assignment");
    $display("PASSED");
  end
endmodule

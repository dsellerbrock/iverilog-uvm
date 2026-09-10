module test;
  covergroup cg(int hi) with function sample(int v);
    cp: coverpoint v { bins b[] = {[0:hi]}; }
  endgroup
  covergroup unused with function sample(int v);
    cp: coverpoint v { bins b[] = {[0:1]}; }
  endgroup
  covergroup no_items;
    option.weight = 0;
  endgroup
  no_items empty_instance;
  cg a,b;
  initial begin
    if ($get_coverage()!=100.0) $fatal(1,"no instances");
    a=new(-1);
    if ($get_coverage()!=100.0) $fatal(1,"only excluded instances");
    empty_instance=new;
    if (empty_instance.get_inst_coverage()!=100.0) $fatal(1,"zero-weight empty group");
    b=new(1); b.sample(0);
    if ($get_coverage()!=50.0) $fatal(1,"excluded type/instance depresses average");
    $display("PASSED");
  end
endmodule

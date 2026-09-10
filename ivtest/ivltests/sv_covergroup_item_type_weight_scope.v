module test;
  localparam int arg=9;
  localparam int packet=9;
  localparam int outer_weight=3;
  covergroup cg(logic [2:0] arg) with function sample(int x,bit y,logic [4:0] packet);
    type_option.merge_instances=1;
    type_option.weight=$bits(arg);
    option.get_inst_coverage=1;
    cx: coverpoint x { type_option.weight=$bits(arg); bins b[]={0,1}; }
    cy: coverpoint y { option.weight=0; type_option.weight=0; }
    xy: cross cx,cy { type_option.weight=$bits(packet); }
  endgroup
  covergroup outer_cg with function sample(int x,int y);
    type_option.merge_instances=1;
    cx: coverpoint x { type_option.weight=outer_weight; bins b[]={0,1}; }
    cy: coverpoint y { bins b[]={0,1}; }
  endgroup
  function automatic int weight_fn();
    return arg/3;
  endfunction
  covergroup function_cg(int arg) with function sample(int x,int y);
    type_option.merge_instances=1;
    type_option.weight=weight_fn();
    cx: coverpoint x { type_option.weight=weight_fn(); bins b[]={0,1}; }
    cy: coverpoint y { bins b[]={0,1}; }
  endgroup
  function_cg f;
  cg c;
  outer_cg o;
  initial begin
    c=new(0); c.sample(0,0,0);
    f=new(21); f.sample(0,2);
    o=new; o.sample(0,2);
    if (c.get_coverage()!=34.375) $fatal(1,"type query lost formal widths");
    if (c.get_inst_coverage()!=37.5) $fatal(1,"type query changed instance weights");
    if (o.get_coverage()!=37.5) $fatal(1,"outer constant binding not restored");
    // Type-query and function group weights are3; outer_cg defaults1.
    if (f.get_coverage()!=37.5) $fatal(1,"outer function captured constructor formal");
    if (!($get_coverage()>36.16071 && $get_coverage()<36.16072))
      $fatal(1,"group function lost lexical weight");
    $display("PASSED"); $finish(0);
  end
endmodule

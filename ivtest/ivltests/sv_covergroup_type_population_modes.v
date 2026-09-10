module test;
  covergroup weighted(int w) with function sample(bit x);
    option.weight=w;
    type_option.weight=5;
    cp: coverpoint x;
  endgroup
  covergroup empty_cg(int n) with function sample(int x);
    type_option.merge_instances=1;
    type_option.weight=11;
    cp: coverpoint x { bins b[]={[0:n-1]}; }
  endgroup
  covergroup disabled_type with function sample(bit x);
    type_option.merge_instances=1;
    type_option.weight=0;
    cp: coverpoint x;
  endgroup
  weighted a,b;
  empty_cg e;
  disabled_type d;
  task automatic ck(string label,real want);
    if ($get_coverage()!=want)
      $fatal(1,"%s overall %f expected %f",label,$get_coverage(),want);
  endtask
  initial begin
    ck("no instances in either mode",100.0);
    a=new(0); a.sample(0); a.sample(1);
    e=new(0); d=new;
    ck("excluded populations keep empty denominator",100.0);
    a=null; e=null; d=null;
    ck("retired excluded populations",100.0);
    b=new(1); b.sample(0);
    ck("merge0 uses contributing instance weights",50.0);
    b=null;
    ck("retired merge0 population",50.0);
    $display("PASSED"); $finish(0);
  end
endmodule

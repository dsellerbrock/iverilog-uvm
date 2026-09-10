module test;
  covergroup cg(longint w) with function sample(int v);
    option.weight = w;
    cp: coverpoint v { bins b[] = {[0:1]}; }
  endgroup
  covergroup merged(int inst) with function sample(int v);
    type_option.merge_instances = 1;
    option.get_inst_coverage = inst;
    cp: coverpoint v { bins b[] = {[0:1]}; }
  endgroup
  covergroup empty_range(int lo, int hi, int w) with function sample(int v);
    option.weight = w;
    cp: coverpoint v { bins b[] = {[lo:hi]}; }
  endgroup
  covergroup truncated with function sample(int v);
    type_option.merge_instances = 2;
    cp: coverpoint v { bins b[] = {[0:1]}; }
  endgroup
  truncated t,u;
  cg a,b,c;
  merged d,e;
  empty_range f,g,h;
  task automatic ck(string name, real got, real want);
    if (got != want) $fatal(1,"%s got %0.4f want %0.4f",name,got,want);
  endtask
  initial begin
    a=new(64'h100000001); b=new(3);
    ck("weight assignment truncation",a.option.weight,1.0);
    a.sample(0);
    ck("unequal unsampled",a.get_coverage(),12.5);
    b.sample(1); ck("complementary half",a.get_coverage(),50.0);
    a.sample(1); ck("weighted",a.get_coverage(),62.5);
    b.option.weight=1;
    ck("read weight",b.option.weight,1.0);
    ck("changed weight",a.get_coverage(),75.0);
    b=null; ck("retired",a.get_coverage(),75.0);
    c=new(2); ck("new unsampled",a.get_coverage(),37.5);
    c.option.weight=0; ck("zero weight",a.get_coverage(),75.0);
    d=new(-2); e=new(3); d.sample(0); e.sample(1);
    ck("Boolean assignment",d.option.get_inst_coverage,0.0);
    ck("Boolean width",$bits(d.option.get_inst_coverage),1.0);
    ck("merged",d.get_coverage(),100.0);
    ck("default merged instance query",d.get_inst_coverage(),100.0);
    ck("enabled instance query",e.get_inst_coverage(),50.0);
    f=new(0,1,1); g=new(3,2,1); h=new(3,2,0);
    f.sample(0); f.sample(1);
    ck("empty excluded",f.get_coverage(),100.0);
    ck("empty instance",g.get_inst_coverage(),0.0);
    ck("empty zero weight instance",h.get_inst_coverage(),100.0);
    t=new; u=new; t.sample(0); u.sample(1);
    ck("merge bit assignment",t.get_coverage(),50.0);
    $display("PASSED");
  end
endmodule

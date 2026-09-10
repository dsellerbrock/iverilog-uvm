module test;
  covergroup dynamic_cg(int hi) with function sample(int x,bit y);
    type_option.merge_instances=1;
    option.get_inst_coverage=1;
    cx: coverpoint x { option.weight=3; bins b[]={[0:hi]}; }
    cy: coverpoint y { option.weight=0; type_option.weight=0; }
    xy: cross cx,cy { type_option.weight=3; }
  endgroup
  covergroup static_cg with function sample(bit x,bit y);
    type_option.merge_instances=1;
    option.get_inst_coverage=1;
    cx: coverpoint x { option.weight=3; }
    cy: coverpoint y { option.weight=0; type_option.weight=0; }
    xy: cross cx,cy { type_option.weight=3; }
  endgroup
  covergroup implicit_cg with function sample(bit x,bit y);
    type_option.merge_instances=1;
    xy: cross x,y { type_option.weight=3; }
  endgroup
  dynamic_cg a,b;
  static_cg s;
  implicit_cg i;
  task automatic ck(string label,real got,real want);
    if (!(got > want-0.000001 && got < want+0.000001))
      $fatal(1,"%s got %f expected %f",label,got,want);
  endtask
  initial begin
    a=new(1); s=new; i=new;
    a.sample(0,0); s.sample(0,0); i.sample(0,0);
    ck("dynamic cross type weight",a.get_coverage(),31.25);
    ck("dynamic cross instance weights",a.get_inst_coverage(),43.75);
    ck("static cross type weight",s.get_coverage(),31.25);
    ck("static cross instance weights",s.get_inst_coverage(),43.75);
    ck("implicit coverpoints receive defaults",i.get_coverage(),35.0);
    b=new(2);
    ck("unsampled constructor expands weighted universe",a.get_coverage(),125.0/6.0);
    b.sample(2,1);
    ck("merged cross count and weight",a.get_coverage(),250.0/6.0);
    b=null;
    ck("retired universe retains type weight",a.get_coverage(),250.0/6.0);
    $display("PASSED"); $finish(0);
  end
endmodule

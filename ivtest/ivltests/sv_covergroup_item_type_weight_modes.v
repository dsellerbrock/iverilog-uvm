module test;
  covergroup cg(int w,int item_w) with function sample(int x,int y);
    option.weight=w;
    cx: coverpoint x { option.weight=item_w; type_option.weight=0; bins b[]={0,1}; }
    cy: coverpoint y { type_option.weight=9; bins b[]={0,1}; }
  endgroup
  cg a,b;
  task automatic ck(string label,real got,real want);
    if (!(got > want-0.000001 && got < want+0.000001))
      $fatal(1,"%s got %f expected %f",label,got,want);
  endtask
  initial begin
    a=new(1,1); b=new(3,3);
    a.sample(0,2); b.sample(0,2);
    ck("first instance uses instance weights",a.get_inst_coverage(),25.0);
    ck("constructor instance item weight",b.get_inst_coverage(),37.5);
    ck("merge0 ignores item type weights",a.get_coverage(),34.375);
    b=null;
    ck("merge0 retired weighted instance",a.get_coverage(),34.375);
    $display("PASSED"); $finish(0);
  end
endmodule

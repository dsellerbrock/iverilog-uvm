module test;
  covergroup cg(int lo,int hi) with function sample(int x,bit y);
    type_option.merge_instances=1;
    cx: coverpoint x { option.weight=0; bins b[] = {[lo:hi]}; }
    cy: coverpoint y { option.weight=0; }
    xy: cross cx,cy { option.at_least=2; }
  endgroup
  covergroup zero_cg(int hi) with function sample(int x,bit y);
    type_option.merge_instances=1;
    cx: coverpoint x { option.weight=0; bins b[] = {[0:hi]}; }
    cy: coverpoint y { option.weight=0; }
    xy: cross cx,cy { option.at_least=0; }
  endgroup
  cg a,b;
  zero_cg c,d;
  task automatic ck(string tag,real got,real want);
    if (!(got > want-0.000001 && got < want+0.000001))
      $fatal(1,"%s got %f expected %f",tag,got,want);
  endtask
  initial begin
    a=new(0,1); b=new(1,2);
    a.sample(0,0); b.sample(1,0);
    ck("local ordinal is not shared count",a.get_coverage(),0.0);
    a.sample(1,0);
    ck("shared tuple threshold",a.get_coverage(),100.0/6.0);
    a.sample(0,0);
    ck("second tuple threshold",a.get_coverage(),200.0/6.0);
    c=new(1); d=new(2);
    ck("zero threshold unsampled",c.get_coverage(),100.0);
    $display("PASSED"); $finish(0);
  end
endmodule

// IEEE 1800-2017/2023 19.11.3: merged cross bins use full tuple names.
module test;
  covergroup cg(int lo, int hi) with function sample(int x, bit y);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    cx: coverpoint x { option.weight=0; type_option.weight=0; bins b[] = {[lo:hi]}; }
    cy: coverpoint y { option.weight=0; type_option.weight=0; }
    xy: cross cx,cy;
  endgroup
  cg a,b,c,empty_instance;
  task automatic ck(string tag, real got, real want);
    if (!(got > want-0.000001 && got < want+0.000001))
      $fatal(1,"%s got %f expected %f",tag,got,want);
  endtask
  initial begin
    a=new(0,1); a.sample(0,0);
    ck("first instance",a.get_coverage(),25.0);
    b=new(1,2);
    ck("unsampled union",a.get_coverage(),100.0/6.0);
    b.sample(1,0); // Same local route number as a's (0,0), different name.
    ck("distinct names",b.get_coverage(),200.0/6.0);
    ck("overall query",$get_coverage(),200.0/6.0);
    ck("instance unchanged",a.get_inst_coverage(),25.0);
    a.sample(1,0); // Same name as b's hit, a different local route number.
    ck("overlapping name",a.get_coverage(),200.0/6.0);
    b=null;
    ck("retired instance",a.get_coverage(),200.0/6.0);
    c=new(1,2); c.sample(2,1);
    ck("recreated universe",c.get_coverage(),50.0);
    empty_instance=new(1,0);
    ck("empty instance",a.get_coverage(),50.0);
    $display("PASSED"); $finish(0);
  end
endmodule

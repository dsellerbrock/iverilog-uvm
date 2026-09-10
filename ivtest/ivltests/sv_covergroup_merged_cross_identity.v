module test;
  covergroup kinds(int lo,int hi) with function sample(int x,bit y);
    type_option.merge_instances=1;
    cx: coverpoint x {
      option.weight=0;
      bins by_value[] = {[lo:hi]};
      bins by_index[2] = {[lo:hi]};
      bins scalar = {[lo:hi]};
    }
    cy: coverpoint y { option.weight=0; }
    xy: cross cx,cy;
  endgroup
  covergroup dimensions(int hi) with function sample(int x,int y,bit z);
    type_option.merge_instances=1;
    cx: coverpoint x { option.weight=0; bins b[] = {[0:hi]}; }
    cy: coverpoint y { option.weight=0; bins b[] = {[0:hi]}; }
    cz: coverpoint z { option.weight=0; }
    xyz: cross cx,cy,cz;
  endgroup
  kinds a,b;
  dimensions c;
  task automatic ck(string tag, real got, real want);
    if (!(got > want-0.000001 && got < want+0.000001))
      $fatal(1,"%s got %f expected %f",tag,got,want);
  endtask
  initial begin
    a=new(0,1); b=new(4,5);
    a.sample(0,0); b.sample(4,0);
    // Four value names, two fixed indexes and one scalar name, crossed by2.
    ck("value versus index identity",a.get_coverage(),400.0/14.0);
    ck("merged instance dispatch",b.get_inst_coverage(),400.0/14.0);
    c=new(1); c.sample(0,1,0); c.sample(1,0,0);
    ck("ordered dimensions",c.get_coverage(),25.0);
    $display("PASSED"); $finish(0);
  end
endmodule

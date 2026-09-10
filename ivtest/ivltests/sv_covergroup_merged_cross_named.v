module test;
  covergroup cg(int hi) with function sample(int x,bit y,bit enabled);
    type_option.merge_instances=1;
    option.get_inst_coverage=1;
    cx: coverpoint x { option.weight=0; type_option.weight=0; bins b[] = {[0:hi]}; }
    cy: coverpoint y { option.weight=0; type_option.weight=0; }
    xy: cross cx,cy iff(enabled) {
      bins zero = binsof(cx) intersect {0};
      bins zero_again = binsof(cx) intersect {0};
      ignore_bins ignored = binsof(cx) intersect {1} && binsof(cy) intersect {1};
    }
  endgroup
  cg a,b;
  task automatic ck(string tag,real got,real want);
    if (!(got > want-0.000001 && got < want+0.000001))
      $fatal(1,"%s got %f expected %f",tag,got,want);
  endtask
  initial begin
    a=new(1); b=new(2);
    // Two overlapping named bins plus three remaining automatic tuples.
    a.sample(0,0,0); b.sample(2,1,0);
    ck("cross iff",a.get_coverage(),0.0);
    a.sample(0,0,1);
    ck("both named identities",a.get_coverage(),40.0);
    b.sample(2,1,1);
    ck("mixed named and automatic",b.get_coverage(),60.0);
    a.sample(1,1,1);
    ck("ignored tuple",a.get_coverage(),60.0);
    ck("instance topology",a.get_inst_coverage(),200.0/3.0);
    b=null;
    ck("retired named and auto",a.get_coverage(),60.0);
    $display("PASSED"); $finish(0);
  end
endmodule

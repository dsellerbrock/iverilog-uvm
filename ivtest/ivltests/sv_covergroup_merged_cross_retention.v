// IEEE 1800-2023 19.6.1/19.11.3: only active named bins survive retention0.
module test;
  covergroup named_cg(int n) with function sample(int x,bit y);
    type_option.merge_instances=1;
    cx: coverpoint x { option.weight=0; type_option.weight=0; bins b[] = {[0:n-1]}; }
    cy: coverpoint y { option.weight=0; type_option.weight=0; }
    xy: cross cx,cy {
      option.cross_retain_auto_bins=0;
      bins selected = binsof(cx) intersect {2};
    }
  endgroup
  covergroup auto_cg(int n) with function sample(int x,bit y);
    type_option.merge_instances=1;
    cx: coverpoint x { option.weight=0; type_option.weight=0; bins b[] = {[0:n-1]}; }
    cy: coverpoint y { option.weight=0; type_option.weight=0; }
    xy: cross cx,cy { option.cross_retain_auto_bins=0; }
  endgroup
  named_cg a,b;
  auto_cg c,d;
  real got;
  initial begin
    a=new(2); a.sample(0,0);
    if (a.get_coverage()!=0.0) $fatal(1,"inactive named bin contributes");
    if ($get_coverage()!=100.0) $fatal(1,"empty cross contributes overall weight");
    b=new(3); b.sample(0,0);
    if (b.get_coverage()!=0.0) $fatal(1,"unretained auto bin counted");
    b.sample(2,1);
    if (a.get_coverage()!=100.0) $fatal(1,"active named type bin missing");
    c=new(2); d=new(3); c.sample(0,0); d.sample(2,1);
    got=c.get_coverage();
    if (!(got > 33.33332 && got < 33.33334))
      $fatal(1,"automatic-only retention got %f",got);
    $display("PASSED"); $finish(0);
  end
endmodule

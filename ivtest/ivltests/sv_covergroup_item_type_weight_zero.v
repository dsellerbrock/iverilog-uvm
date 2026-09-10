module test;
  covergroup cg with function sample(bit x,bit y);
    type_option.merge_instances=1;
    option.get_inst_coverage=1;
    cx: coverpoint x { type_option.weight=0; }
    cy: coverpoint y { type_option.weight=0; }
    xy: cross cx,cy { type_option.weight=0; }
  endgroup
  cg c;
  initial begin
    c=new; c.sample(0,0);
    if (c.get_coverage()!=0.0) $fatal(1,"zero type weights contribute");
    if ($get_coverage()!=100.0) $fatal(1,"zero-weight type enters overall denominator");
    if (!(c.get_inst_coverage()>41.66666 && c.get_inst_coverage()<41.66668))
      $fatal(1,"type weights changed instance score");
    $display("PASSED"); $finish(0);
  end
endmodule

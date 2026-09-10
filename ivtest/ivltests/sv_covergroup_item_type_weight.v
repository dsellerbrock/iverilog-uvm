// IEEE 1800-2017/2023 19.7.1 and 19.11.3: item type weights are
// independent of instance weights, including omitted defaults.
module test;
  covergroup explicit_cg with function sample(int x,int y);
    type_option.merge_instances=1;
    type_option.weight=7;
    option.get_inst_coverage=1;
    cx: coverpoint x { type_option.weight=64'h100000003; bins b[]={0,1}; }
    cy: coverpoint y { option.weight=3; type_option.weight=1; bins b[]={0,1}; }
  endgroup
  covergroup defaults_cg with function sample(int x,int y);
    type_option.merge_instances=1;
    type_option.weight=7;
    option.weight=9;
    option.get_inst_coverage=1;
    cx: coverpoint x { option.weight=0; bins b[]={0,1}; }
    cy: coverpoint y { option.weight=9; bins b[]={0,1}; }
  endgroup
  covergroup rounded_cg with function sample(int x,int y);
    type_option.merge_instances=1;
    cx: coverpoint x { type_option.weight=1.5; bins b[]={0,1}; }
    cy: coverpoint y { bins b[]={0,1}; }
  endgroup
  explicit_cg a;
  defaults_cg b;
  rounded_cg c;
  task automatic ck(string label,real got,real want);
    if (!(got > want-0.000001 && got < want+0.000001))
      $fatal(1,"%s got %f expected %f",label,got,want);
  endtask
  initial begin
    a=new; b=new; c=new;
    a.sample(0,2); b.sample(0,2); c.sample(0,2);
    ck("declared type weights after int truncation",a.get_coverage(),37.5);
    ck("ordinary instance weights",a.get_inst_coverage(),12.5);
    ck("independent default type weights",b.get_coverage(),25.0);
    ck("instance zero weight retained",b.get_inst_coverage(),0.0);
    ck("typed constant rounding",c.get_coverage(),100.0/3.0);
    a.cy.option.weight=0;
    ck("procedural instance option leaves type unchanged",a.get_coverage(),37.5);
    ck("procedural instance option takes effect",a.get_inst_coverage(),50.0);
    $display("PASSED"); $finish(0);
  end
endmodule

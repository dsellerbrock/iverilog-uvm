module test;
  covergroup hit with function sample(bit x);
    type_option.merge_instances=1;
    cp: coverpoint x { bins yes={1}; }
  endgroup
  covergroup dynamic_cg(int n) with function sample(int x,bit state);
    type_option.merge_instances=1;
    type_option.weight=3;
    option.weight=0;
    cx: coverpoint x { option.weight=0; type_option.weight=0; bins b[]={[0:n-1]}; }
    cs: coverpoint state {
      option.weight=0; type_option.weight=0;
      bins rise=(0=>1); bins fall=(1=>0);
    }
    xs: cross cx,cs;
  endgroup
  hit a;
  dynamic_cg b,c;
  task automatic ck(string label,real want);
    real got=$get_coverage();
    if (!(got>want-0.000001 && got<want+0.000001))
      $fatal(1,"%s overall %f expected %f",label,got,want);
  endtask
  initial begin
    ck("no dynamic population",100.0);
    a=new; a.sample(1);
    ck("unused dynamic cross does not contribute",100.0);
    b=new(2);
    ck("new dynamic universe contributes",25.0);
    b.sample(0,0); b.sample(0,1);
    ck("one transition product hit",43.75);
    b=null;
    ck("retired cross universe",43.75);
    c=new(3);
    ck("unsampled construction extends retired union",37.5);
    c=null;
    b=new(0);
    ck("empty new topology keeps historical population",37.5);
    a=null; b=null;
    ck("retired population remains",37.5);
    $display("PASSED"); $finish(0);
  end
endmodule

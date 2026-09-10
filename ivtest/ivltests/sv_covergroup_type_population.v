// IEEE 1800-2017/2023 19.11,19.11.3: only actual instance populations
// contribute, and retirement does not discard cumulative coverage.
module test;
  covergroup hit with function sample(bit x);
    type_option.merge_instances=1;
    cp: coverpoint x { bins yes={1}; }
  endgroup
  covergroup future with function sample(bit x);
    type_option.merge_instances=1;
    type_option.weight=3;
    option.weight=0;
    cp: coverpoint x;
  endgroup
  covergroup never_used with function sample(bit x);
    type_option.merge_instances=1;
    type_option.weight=99;
    cp: coverpoint x { option.at_least=0; }
  endgroup
  hit a;
  future b;
  never_used n;
  task automatic ck(string label,real want);
    if ($get_coverage()!=want)
      $fatal(1,"%s overall %f expected %f",label,$get_coverage(),want);
  endtask
  initial begin
    ck("no instances",100.0);
    a=new;
    ck("unused at_least0 type must not inflate score",0.0);
    a.sample(1);
    ck("one fully covered type",100.0);
    b=new;
    ck("constructed unsampled type enters denominator",25.0);
    b.sample(0);
    ck("partial weighted population",62.5);
    b=null;
    ck("retired zero-instance-weight type remains",62.5);
    a=null;
    ck("all instances retired",62.5);
    b=new; b.sample(1);
    ck("recreated type extends retained counts",100.0);
    $display("PASSED"); $finish(0);
  end
endmodule

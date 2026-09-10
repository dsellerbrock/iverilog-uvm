// IEEE 1800-2017/2023 19.6, 19.11.3: transition source names remain
// distinct within the merged cross tuple, including arrayed transition bins.
module test;
  covergroup cg(int lo, int hi) with function sample(int state, int x);
    type_option.merge_instances=1;
    option.get_inst_coverage=1;
    cs: coverpoint state {
      option.weight=0;
      bins rise = (0 => 1);
      bins paths[] = (2, 3 => 4);
    }
    cx: coverpoint x { option.weight=0; bins b[] = {[lo:hi]}; }
    sx: cross cs,cx { option.at_least=2; }
  endgroup
  cg a,b;
  task automatic ck(string tag, real got, real want);
    if (!(got > want-0.000001 && got < want+0.000001))
      $fatal(1,"%s got %f expected %f",tag,got,want);
  endtask
  initial begin
    a=new(0,1); b=new(1,2);
    a.sample(4,0); b.sample(1,1);
    ck("final values alone",a.get_coverage(),0.0);
    a.sample(2,0); a.sample(4,0);
    b.sample(3,1); b.sample(4,1);
    ck("distinct path tuples below threshold",a.get_coverage(),0.0);
    a.sample(3,1); a.sample(4,1);
    ck("shared arrayed transition tuple",a.get_coverage(),100.0/9.0);
    b.sample(2,1); b.sample(4,1);
    ck("other arrayed path remains distinct",a.get_coverage(),100.0/9.0);
    a.sample(2,1); a.sample(4,1);
    ck("second arrayed transition tuple",a.get_coverage(),200.0/9.0);
    a.sample(0,1); a.sample(1,1);
    b.sample(0,1); b.sample(1,1);
    ck("named transition tuple",a.get_coverage(),300.0/9.0);
    ck("local counts stay below threshold",a.get_inst_coverage(),0.0);
    b=null;
    ck("transition universe survives retirement",a.get_coverage(),300.0/9.0);
    $display("PASSED"); $finish(0);
  end
endmodule

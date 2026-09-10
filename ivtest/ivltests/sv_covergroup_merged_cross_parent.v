module test;
  class holder;
    int values[$];
    int x;
    bit y;
    covergroup cg;
      type_option.merge_instances=1;
      cx: coverpoint x { option.weight=0; bins b[] = values; }
      cy: coverpoint y { option.weight=0; }
      xy: cross cx,cy;
    endgroup
    function new(int lo);
      values.push_back(lo); values.push_back(lo+1);
      cg=new;
      values[0]=99; // The constructor-time set must already be frozen.
    endfunction
    function void sample(int observed,bit flag);
      x=observed; y=flag; cg.sample();
    endfunction
    function real coverage(); return cg.get_coverage(); endfunction
  endclass
  holder a,b;
  real got;
  initial begin
    a=new(0); b=new(1);
    a.sample(0,0); b.sample(2,1);
    got=a.coverage();
    if (!(got > 33.33332 && got < 33.33334))
      $fatal(1,"post-link captured union got %f",got);
    $display("PASSED"); $finish(0);
  end
endmodule

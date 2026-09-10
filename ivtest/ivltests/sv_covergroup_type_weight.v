module test;
  covergroup low with function sample(int v);
    option.weight=4;
    cp: coverpoint v { bins b[]={[0:1]}; }
  endgroup
  covergroup high with function sample(int v);
    type_option.weight=64'h100000003;
    cp: coverpoint v { bins b[]={[0:1]}; }
  endgroup
  covergroup zero_weight with function sample(int v);
    type_option.weight='x;
    cp: coverpoint v { bins b[]={[0:1]}; }
  endgroup
  covergroup empty(int lo,int hi) with function sample(int v);
    type_option.weight=7;
    cp: coverpoint v { bins b[]={[lo:hi]}; }
  endgroup
  covergroup unused with function sample(int v);
    type_option.weight=32'h7fffffff;
    cp: coverpoint v { bins b[]={[0:1]}; }
  endgroup
  low a; high b; zero_weight z; empty e;
  task automatic ck(real expected);
    if ($get_coverage()!=expected)
      $fatal(1,"weighted overall got %0.2f expected %0.2f",$get_coverage(),expected);
  endtask
  initial begin
    ck(100.0);
    a=new; b=new; z=new; e=new(3,2);
    b.sample(0); ck(37.5);
    a.sample(0); ck(50.0);
    b.sample(1); ck(87.5);
    if (a.get_coverage()!=50.0 || b.get_coverage()!=100.0)
      $fatal(1,"type weights changed individual type scores");
    b=null; ck(87.5);
    a.sample(1); ck(100.0);
    $display("PASSED");
  end
endmodule

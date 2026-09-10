// IEEE 1800-2017/2023 19.11.3: merge the bin-name universe, not just hits.
module test;
  covergroup overlap(int lo, int hi) with function sample(int v);
    type_option.merge_instances = 1;
    cp: coverpoint v { bins b[] = {[lo:hi]}; }
  endgroup
  covergroup disjoint(int lo, int hi) with function sample(int v);
    type_option.merge_instances = 1;
    cp: coverpoint v { bins b[] = {[lo:hi]}; }
  endgroup
  covergroup threshold(int lo, int hi) with function sample(int v);
    type_option.merge_instances = 1;
    cp: coverpoint v { option.at_least = 2; bins b[] = {[lo:hi]}; }
  endgroup
  covergroup signed_range(int lo, int hi) with function sample(int v);
    type_option.merge_instances = 1;
    cp: coverpoint v { bins b[] = {[lo:hi]}; }
  endgroup
  covergroup fixed_bins(int lo, int hi) with function sample(int v);
    type_option.merge_instances = 1;
    cp: coverpoint v { bins b[2] = {[lo:hi]}; }
  endgroup
  covergroup scalar_bin(int lo, int hi) with function sample(int v);
    type_option.merge_instances = 1;
    cp: coverpoint v { bins b = {[lo:hi]}; }
  endgroup
  covergroup wide(bit [63:0] lo, bit [63:0] hi)
      with function sample(bit [63:0] v);
    type_option.merge_instances = 1;
    cp: coverpoint v { option.at_least = 0; bins b[] = {[lo:hi]}; }
  endgroup
  overlap a,b;
  disjoint c,d;
  threshold e,f;
  signed_range g,h;
  fixed_bins i,j;
  scalar_bin k,l;
  wide m,n;
  task automatic ck(string tag, real got, real want);
    if (got < want-0.000001 || got > want+0.000001)
      $fatal(1,"%s got %0.8f expected %0.8f",tag,got,want);
  endtask
  initial begin
    a=new(0,1); b=new(1,2);
    a.sample(0); a.sample(1); b.sample(1);
    ck("LRM overlap",a.get_coverage(),200.0/3.0);
    c=new(0,1); c.sample(0); d=new(4,5);
    ck("unsampled disjoint",c.get_coverage(),25.0);
    d.sample(4);
    ck("partial disjoint",d.get_coverage(),50.0);
    d=null;
    ck("retired universe",c.get_coverage(),50.0);
    e=new(0,1); f=new(1,2); e.sample(1); f.sample(1);
    ck("merged hit threshold",e.get_coverage(),100.0/3.0);
    g=new(-2,0); h=new(0,1); g.sample(-2); h.sample(1);
    ck("signed crossing",g.get_coverage(),50.0);
    i=new(0,1); j=new(4,5); i.sample(0); j.sample(4);
    ck("fixed index identity",i.get_coverage(),50.0);
    k=new(0,1); l=new(4,5); k.sample(0);
    ck("scalar name identity",l.get_coverage(),100.0);
    m=new(0,64'hffffffffffffffff); n=new(1,64'hffffffffffffffff);
    ck("full width no enumeration",m.get_coverage(),100.0);
    $display("PASSED");
  end
endmodule

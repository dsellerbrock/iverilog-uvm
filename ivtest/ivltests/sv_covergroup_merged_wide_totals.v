// IEEE 1800-2017/2023 19.11.3: retain every named bin in merged ratios.
module test;
  covergroup wide(bit [63:0] lo, bit [63:0] hi)
      with function sample(bit [63:0] v);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    cp: coverpoint v {
      bins first[] = {[lo:hi]};
      bins second[] = {[lo:hi]};
    }
  endgroup
  covergroup unequal(bit [63:0] hi) with function sample(bit [63:0] v);
    type_option.merge_instances = 1;
    cp: coverpoint v {
      bins first[] = {[0:hi]};
      bins second[] = {[0:hi >> 1]};
      bins third[] = {[0:hi >> 2]};
    }
  endgroup
  covergroup threshold(bit [63:0] hi) with function sample(bit [63:0] v);
    type_option.merge_instances = 1;
    cp: coverpoint v {
      option.at_least = 2;
      bins first[] = {[0:hi]};
      bins second[] = {[0:hi]};
    }
  endgroup
  covergroup zero_threshold(bit [63:0] hi) with function sample(bit [63:0] v);
    type_option.merge_instances = 1;
    cp: coverpoint v {
      option.at_least = 0;
      bins first[] = {[0:hi]};
      bins second[] = {[0:hi]};
    }
  endgroup
  covergroup mixed(bit [63:0] hi) with function sample(bit [63:0] v);
    type_option.merge_instances = 1;
    cp: coverpoint v {
      bins first[] = {[0:hi]};
      bins second[] = {[0:hi]};
      bins named = {0};
    }
  endgroup
  covergroup weighted(bit [63:0] hi) with function sample(bit [63:0] v);
    type_option.merge_instances = 1;
    cp_large: coverpoint v { option.weight = 1; bins b[] = {[0:hi]}; }
    cp_small: coverpoint v { option.weight = 3; bins a = {0}; bins b = {1}; }
  endgroup
  covergroup small_domain(int hi) with function sample(int v);
    type_option.merge_instances = 1;
    cp: coverpoint v { bins a[] = {[0:hi]}; bins b[] = {[0:hi]}; }
  endgroup
  wide a,b;
  unequal c;
  threshold d,e;
  zero_threshold f;
  mixed g;
  weighted h;
  small_domain i,j;
  real domain, unit;
  task automatic ck(string tag, real got, real want);
    real ratio;
    if (want == 0.0) begin
      if (got != 0.0) $fatal(1,"%s expected zero, got %e",tag,got);
    end else begin
      ratio = got / want;
      if (!(ratio >= 0.999999 && ratio <= 1.000001))
        $fatal(1,"%s got %e expected %e ratio %f",tag,got,want,ratio);
    end
  endtask
  initial begin
    domain = 18446744073709551616.0;
    unit = 100.0 / domain;
    a=new(0,64'h7fffffffffffffff); a.sample(0);
    ck("half universe",a.get_coverage(),2.0*unit);
    b=new(64'h8000000000000000,64'hffffffffffffffff);
    ck("unsampled disjoint universe",a.get_coverage(),unit);
    b.sample(64'h8000000000000000);
    ck("two named full universes",a.get_coverage(),2.0*unit);
    ck("independent instance",a.get_inst_coverage(),2.0*unit);
    b=null;
    ck("retired universe and hits",a.get_coverage(),2.0*unit);
    c=new(64'hffffffffffffffff); c.sample(0);
    ck("three unequal families",c.get_coverage(),300.0/(1.75*domain));
    d=new(64'hffffffffffffffff); e=new(64'hffffffffffffffff);
    d.sample(0); ck("below threshold",d.get_coverage(),0.0);
    e.sample(0); ck("merged threshold",d.get_coverage(),unit);
    f=new(64'hffffffffffffffff);
    ck("zero threshold",f.get_coverage(),100.0);
    g=new(64'hffffffffffffffff); g.sample(0);
    ck("static plus dynamic",g.get_coverage(),300.0/(2.0*domain+1.0));
    h=new(64'hffffffffffffffff); h.sample(0);
    ck("separate weighted items",h.get_coverage(),(unit+150.0)/4.0);
    i=new(-1); ck("empty universe",i.get_coverage(),0.0);
    j=new(3); j.sample(0);
    ck("small exact ratio",j.get_coverage(),25.0);
    $display("PASSED");
    $finish(0);
  end
endmodule

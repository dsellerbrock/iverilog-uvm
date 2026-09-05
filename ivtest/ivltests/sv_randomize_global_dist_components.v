// IEEE 1800-2017 18.5.4/18.5.9/18.5.10;
// IEEE 1800-2023 18.5.3/18.5.8/18.5.9. Object RNG: both editions 18.14.1/.3.
class leaf;
  rand bit value;
endclass
class root;
  rand leaf child;
  rand bit value, independent;
  int low_weight=1, high_weight=1;
  function new(); child=new; endfunction
  constraint c {
    value dist {0 := low_weight, 1 := high_weight};
    child.value <= value;
    independent dist {0 := 6, 1 := 4};
  }
endclass
class weighted_bins;
  rand leaf child;
  rand int unsigned value;
  function new(); child=new; endfunction
  constraint c { value dist {[0:19] :/ 1, [20:59] :/ 1, [60:99] :/ 1, 100 :/ 1}; }
endclass
module main;
  root r=new;
  weighted_bins b=new;
  int count[4], bins_count[4], independent_count;
  bit [2:0] replay[12];
  string rs, cs;
  initial begin
    r.srandom(71); r.child.srandom(73);
    repeat (2400) begin
      if (!r.randomize()) $fatal(1,"joint distribution failed");
      count[{r.value,r.child.value}]++;
      independent_count+=int'(r.independent);
    end
    if (count[1] || count[0]<1050 || count[0]>1350 || count[2]<480
        || count[2]>720 || count[3]<480 || count[3]>720
        || independent_count<810 || independent_count>1110)
      $fatal(1,"dist marginal or conditional tuple distribution incorrect");
    rs=r.get_randstate(); cs=r.child.get_randstate();
    for (int i=0;i<12;i++) begin
      if (!r.randomize()) $fatal(1,"replay setup failed");
      replay[i]={r.value,r.child.value,r.independent};
    end
    r.set_randstate(rs); r.child.set_randstate(cs);
    for (int i=0;i<12;i++) begin
      if (!r.randomize() || replay[i]!={r.value,r.child.value,r.independent})
        $fatal(1,"joint dist RNG replay changed");
    end
    r.low_weight=0; r.high_weight=1;
    repeat (20) if (!r.randomize() || r.value!=1) $fatal(1,"zero weight ignored");
    b.srandom(79); b.child.srandom(83);
    repeat (400) begin
      if (!b.randomize() || b.value>100) $fatal(1,"independent weighted bins failed");
      if (b.value<20) bins_count[0]++;
      else if (b.value<60) bins_count[1]++;
      else if (b.value<100) bins_count[2]++;
      else bins_count[3]++;
    end
    foreach (bins_count[i]) if (bins_count[i]<55 || bins_count[i]>145)
      $fatal(1,"range weight was applied per value");
    $display("PASSED");
  end
endmodule

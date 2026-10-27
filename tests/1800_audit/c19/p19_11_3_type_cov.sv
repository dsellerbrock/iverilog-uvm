module p19_11_3_type_cov;
  bit [7:0] a;
  covergroup gta(int l, int h);
    option.per_instance = 1;
    coverpoint a { bins b[] = {[l:h]}; }
  endgroup
  covergroup gtm(int l, int h);
    option.per_instance = 1;
    type_option.merge_instances = 1;
    coverpoint a { bins b[] = {[l:h]}; }
  endgroup
  covergroup gtw(int l, int h, int w);
    option.per_instance = 1;
    option.weight = w;
    coverpoint a { bins b[] = {[l:h]}; }
  endgroup
  covergroup gl(int al);
    option.per_instance = 1;
    option.at_least = al;
    type_option.merge_instances = 1;
    coverpoint a { bins x = {5}; }
  endgroup
  covergroup ga(int abm);
    option.per_instance = 1;
    option.auto_bin_max = abm;
    type_option.merge_instances = 1;
    coverpoint a { ignore_bins i = {3}; }
  endgroup
  gta a1, a2; gtm m1, m2; gtw w1, w2; gl l1, l2; ga g1, g2;
  int cov, tot;
  initial begin
    a1 = new(0,1); a2 = new(1,2); m1 = new(0,1); m2 = new(1,2);
    w1 = new(0,1,3); w2 = new(1,2,1); l1 = new(1); l2 = new(3);
    g1 = new(64); g2 = new(32);
    a = 0; a1.sample(); m1.sample(); w1.sample();
    a = 1; a1.sample(); a2.sample(); m1.sample(); m2.sample(); w1.sample(); w2.sample();
    $display("AVG  type=%0.2f i1=%0.2f i2=%0.2f", a1.get_coverage(), a1.get_inst_coverage(), a2.get_inst_coverage());
    $display("MRG  type=%0.2f i1=%0.2f i2=%0.2f", m1.get_coverage(), m1.get_inst_coverage(), m2.get_inst_coverage());
    $display("WGT  type=%0.2f", w1.get_coverage());
    a = 5; l1.sample(); l1.sample();
    $display("ATL1 type=%0.2f l1inst=%0.2f", l1.get_coverage(), l1.get_inst_coverage());
    l2.sample();
    $display("ATL2 type=%0.2f", l1.get_coverage());
    a = 0; g1.sample(); g2.sample();
    void'(g1.get_coverage(cov, tot));
    $display("AUTO type=%0.2f cov=%0d tot=%0d", g1.get_coverage(), cov, tot);
  end
endmodule

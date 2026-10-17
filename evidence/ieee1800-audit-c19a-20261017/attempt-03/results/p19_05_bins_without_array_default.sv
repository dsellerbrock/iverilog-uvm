module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  function automatic bit near(real a, real b); return (a - b < 0.01) && (b - a < 0.01); endfunction
  bit [9:0] v_a; bit [3:0] f; bit rst, s;
  covergroup cg1; coverpoint v_a { bins a = { [0:63], 65 }; bins b[] = { [127:150], [148:191] };
    bins c[] = { 200, 201, 202 }; bins d = { [1000:$] };  } endgroup
  covergroup cg2; coverpoint f { bins fixed[4] = { [1:10], 1, 4, 7 }; } endgroup
  covergroup cg3; coverpoint f { bins e[5] = { 1, 4, 7 }; } endgroup
  covergroup cg4; coverpoint s iff (!rst) { bins lo = {0}; bins hi = {1}; } endgroup
  covergroup cg5; endgroup
  covergroup cg6; option.weight = 0; endgroup
  covergroup cg7; coverpoint s { option.weight = 0; bins lo = {0}; } endgroup
  cg1 g1 = new; cg2 g2 = new, g2b = new; cg3 g3 = new; cg4 g4 = new;
  cg5 g5 = new; cg6 g6 = new; cg7 g7 = new;
  int vals[] = '{5, 65, 127, 149, 201, 1023, 500}; int n, d; real r;
  initial begin
    chk("19.11.1.no_samples_0", near(g1.get_inst_coverage(), 0.0));
    foreach (vals[i]) begin v_a = vals[i]; g1.sample(); end
    r = g1.get_inst_coverage(n, d); $display("INFO cg1 cov=%f n=%0d d=%0d", r, n, d);
    chk("19.5.1.bins_default_excluded_5_of_70", near(r, 500.0/70) && n == 5 && d == 70);
    f = 10; g2.sample(); chk("19.5.1.fixed_last_bin_gets_remainder", near(g2.get_inst_coverage(), 25.0));
    f = 4; g2b.sample(); chk("19.5.1.fixed_duplicates_retained", near(g2b.get_inst_coverage(), 50.0));
    f = 4; g3.sample(); r = g3.get_inst_coverage(n, d); $display("INFO cg3 cov=%f n=%0d d=%0d", r, n, d);
    chk("19.11.1.empty_bins_excluded", near(r, 100.0/3) && n == 1 && d == 3);
    rst = 1; s = 1; g4.sample(); chk("19.5.iff_false_ignored", near(g4.get_inst_coverage(), 0.0));
    rst = 0; s = 0; g4.sample(); chk("19.5.iff_true_counts", near(g4.get_inst_coverage(), 50.0));
    r = g5.get_inst_coverage(n, d); chk("19.11.no_items_weight_nonzero_0", near(r, 0.0) && n == 0 && d == 0);
    chk("19.11.no_items_weight_zero_100", near(g6.get_inst_coverage(), 100.0));
    s = 0; g7.sample(); chk("19.11.all_item_weights_zero_0", near(g7.get_inst_coverage(), 0.0));
    $display("DONE fails=%0d", fails);
  end
endmodule

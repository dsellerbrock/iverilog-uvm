// IEEE 1800-2017/2023 §19.7 Tables 19-1 and 19-3: common options.
module test;
  int fails = 0;
  task automatic check(string id, bit ok);
    if (ok) $display("PASS %s", id);
    else begin $display("FAIL %s", id); fails++; end
  endtask
  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  bit [7:0] v;
  bit [4:0] abv;
  bit a, b;

  covergroup cg_at_least;
    option.at_least = 2;
    cp: coverpoint v { bins b0 = {0}; bins b1 = {1}; }
  endgroup

  covergroup cg_weight;
    cp_active: coverpoint a { bins vals[] = {0, 1}; }
    cp_ignored: coverpoint b { option.weight = 0; bins vals[] = {0, 1}; }
  endgroup

  covergroup cg_auto_bins;
    coverpoint abv { option.auto_bin_max = 4; }
  endgroup

  covergroup cg_type_opts;
    type_option.weight = 2;
    type_option.goal = 90;
    coverpoint a;
  endgroup

  cg_at_least c_al = new;
  cg_weight c_wt = new;
  cg_auto_bins c_ab = new;
  cg_type_opts c_to = new;

  initial begin
    v = 0; c_al.sample();
    check("19.07.at_least_1_sample_unmet", c_al.get_inst_coverage() == 0.0);
    c_al.sample();
    check("19.07.at_least_2_samples_met", near(c_al.get_inst_coverage(), 50.0));

    a = 0; b = 0; c_wt.sample();
    a = 1; c_wt.sample();
    check("19.07.option_weight_zero_excluded", near(c_wt.get_inst_coverage(), 100.0));

    abv = 0; c_ab.sample();
    abv = 9; c_ab.sample();
    check("19.07.auto_bin_max_four_bins", near(c_ab.get_inst_coverage(), 50.0));
    check("19.07.type_option_instantiated", c_to != null);

    if (fails == 0) $display("PASS 19.7 common coverage options");
    else $fatal(1, "%0d common coverage option checks failed", fails);
    $finish;
  end
endmodule

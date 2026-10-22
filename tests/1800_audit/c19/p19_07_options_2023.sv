// IEEE 1800-2023 §19.7 / §19.7.1: 2023-only coverage options.
module test_2023;
  int fails = 0;
  task automatic check(string id, bit ok);
    if (ok) $display("PASS %s", id);
    else begin $display("FAIL %s", id); fails++; end
  endtask

  real rv;
  bit a, b;

  covergroup cg_real;
    type_option.real_interval = 0.1;
    cp_real: coverpoint rv { bins b[] = {[0.0:0.3]}; }
  endgroup

  covergroup cg_cross_retain;
    ca: coverpoint a { bins vals[] = {0, 1}; }
    cb: coverpoint b { bins vals[] = {0, 1}; }
    cx: cross ca, cb {
      option.cross_retain_auto_bins = 1;
      bins only00 = binsof(ca) intersect {0} && binsof(cb) intersect {0};
    }
  endgroup

  cg_real cr = new;
  cg_cross_retain cxr = new;

  initial begin
    rv = 0.05; cr.sample();
    check("19.07.real_interval_sample", cr.get_inst_coverage() > 0.0);

    a = 1; b = 1; cxr.sample();
    check("19.07.cross_retain_auto_bins_sample", cxr.get_inst_coverage() > 0.0);

    if (fails == 0) $display("PASS 19.7 2023 coverage options");
    else $fatal(1, "%0d 2023 option checks failed", fails);
    $finish;
  end
endmodule

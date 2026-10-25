module test;
  int fails = 0;
  task automatic check(string id, bit ok);
    if (ok) $display("PASS %s", id);
    else begin $display("FAIL %s", id); fails++; end
  endtask

  bit a, b;
  covergroup cg;
    cp_a: coverpoint a { bins b0 = {0}; bins b1 = {1}; }
    cp_b: coverpoint b { bins b0 = {0}; bins b1 = {1}; }
    cx: cross cp_a, cp_b;
  endgroup

  cg cov = new;

  initial begin
    cov.option.weight = 3;
    check("19.10.cg_option_weight_rw", cov.option.weight == 3);
    cov.cp_a.option.weight = 2;
    check("19.10.cp_option_weight_rw", cov.cp_a.option.weight == 2);
    cov.cp_a.option.at_least = 2;
    check("19.10.cp_option_at_least_rw", cov.cp_a.option.at_least == 2);
    cov.cx.option.weight = 4;
    check("19.10.cross_option_weight_rw", cov.cx.option.weight == 4);
    cov.cx.option.at_least = 3;
    check("19.10.cross_option_at_least_rw", cov.cx.option.at_least == 3);

    if (fails == 0) $display("PASS 19.10 option structure organization");
    else $fatal(1, "%0d checks failed in clause 19.10", fails);
    $finish;
  end
endmodule

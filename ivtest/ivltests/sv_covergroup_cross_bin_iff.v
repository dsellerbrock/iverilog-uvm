// IEEE 1800-2017/2023 19.6: iff at the end of a cross-bin declaration
// suppresses that cross bin for samples where its expression is false.
module main;
  covergroup cg with function sample(bit gate);
    ca: coverpoint gate { bins one = {1}; }
    cb: coverpoint gate { bins one = {1}; }
    cx: cross ca, cb {
      bins gated = binsof(ca.one) && binsof(cb.one) iff (gate);
    }
  endgroup

  cg cov = new;
  initial begin
    cov.sample(0);
    if (cov.cx.get_inst_coverage() != 0.0)
      $fatal(1, "false guard counted");
    cov.sample(1);
    if (cov.cx.get_inst_coverage() != 100.0)
      $fatal(1, "true guard not counted");
    $display("PASS per-bin iff");
    $finish;
  end
endmodule

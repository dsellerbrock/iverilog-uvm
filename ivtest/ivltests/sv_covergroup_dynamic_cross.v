// IEEE 1800-2017/2023 19.3 and 19.6: cross topology is constructed from
// the logical bins of each particular covergroup object. A constructor-
// dependent open bin array therefore contributes a per-instance number of
// cross products, and each product has independent coverage state.
module top;
  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  covergroup cg(int n) with function sample(int idx, bit flag);
    option.per_instance = 1;
    cp_idx: coverpoint idx {
      bins each[] = {[0:n-1]};
    }
    cp_flag: coverpoint flag;
    idx_x_flag: cross cp_idx, cp_flag;
  endgroup

  cg two = new(2);
  cg three = new(3);

  initial begin
    two.sample(0, 0);
    if (!near(two.get_inst_coverage(), 41.6667))
      $fatal(1, "two-bin dynamic cross has the wrong denominator");

    three.sample(2, 1);
    if (!near(three.get_inst_coverage(), 33.3333))
      $fatal(1, "cross topology leaked between covergroup instances");

    for (int idx = 0; idx < 2; idx++)
      for (int flag = 0; flag < 2; flag++)
        two.sample(idx, flag);
    if (two.get_inst_coverage() != 100.0)
      $fatal(1, "dynamic automatic cross did not cover every product");

    if (!near(three.get_inst_coverage(), 33.3333))
      $fatal(1, "sampling one object changed another object's topology");

    $display("PASSED");
    $finish;
  end
endmodule

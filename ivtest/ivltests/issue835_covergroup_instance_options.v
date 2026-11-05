// IEEE 1800-2017/2023 19.7: covergroup option assignments are evaluated
// for each instance, including constructor-dependent automatic bin limits.
module top;
  covergroup cg_group_atleast(int threshold) with function sample(bit [7:0] v);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    option.at_least = threshold;
    cp: coverpoint v { bins zero = {0}; bins one = {1}; }
  endgroup

  covergroup cg_cp_atleast(int threshold) with function sample(bit [7:0] v);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    cp: coverpoint v {
      option.at_least = threshold;
      bins zero = {0}; bins one = {1};
    }
  endgroup

  covergroup cg_cross_atleast(int threshold) with function sample(bit x,
                                                                  bit y);
    option.get_inst_coverage = 1;
    cx: coverpoint x { bins zero = {0}; bins one = {1}; }
    cy: coverpoint y { bins zero = {0}; bins one = {1}; }
    cxy: cross cx, cy { option.at_least = threshold; }
  endgroup

  covergroup cg_group_auto(int limit) with function sample(bit [7:0] x,
                                                            bit [7:0] y);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    option.auto_bin_max = limit;
    cx: coverpoint x { type_option.weight = 0; }
    cy: coverpoint y { type_option.weight = 0; }
    cxy: cross cx, cy { type_option.weight = 1; }
  endgroup

  covergroup cg_cp_auto(int limit) with function sample(bit [7:0] v);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    cp: coverpoint v { option.auto_bin_max = limit; }
  endgroup

  cg_group_atleast group_min3, group_min1;
  cg_cp_atleast cp_min3, cp_min1;
  cg_cross_atleast cross_min3, cross_min1;
  cg_group_auto group_max4, group_max8;
  cg_cp_auto cp_max4, cp_max8;
  int failures = 0;

  task automatic check(string label, real got, real want);
    if (got < want - 0.001 || got > want + 0.001) begin
      failures++;
      $display("FAILED %s got=%0.4f want=%0.4f", label, got, want);
    end
  endtask

  initial begin
    group_min3 = new(3);
    group_min1 = new(1);
    group_min3.sample(0); group_min3.sample(0);
    group_min1.sample(0); group_min1.sample(0);
    check("covergroup at_least=3", group_min3.get_inst_coverage(), 0.0);
    check("covergroup at_least=1", group_min1.get_inst_coverage(), 50.0);
    check("covergroup cumulative at_least=max instance value",
          group_min3.get_coverage(), 50.0);

    cp_min3 = new(3);
    cp_min1 = new(1);
    cp_min3.sample(0); cp_min3.sample(0);
    cp_min1.sample(0); cp_min1.sample(0);
    check("coverpoint at_least=3", cp_min3.get_inst_coverage(), 0.0);
    check("coverpoint at_least=1", cp_min1.get_inst_coverage(), 50.0);
    check("coverpoint cumulative at_least=max instance value",
          cp_min3.get_coverage(), 50.0);

    cross_min3 = new(3);
    cross_min1 = new(1);
    cross_min3.sample(0, 0);
    cross_min1.sample(0, 0);
    check("cross at_least=3", cross_min3.get_inst_coverage(), 100.0 / 3.0);
    check("cross at_least=1", cross_min1.get_inst_coverage(), 125.0 / 3.0);

    group_max4 = new(4);
    group_max8 = new(8);
    group_max4.sample(0, 0);
    group_max8.sample(0, 0);
    check("covergroup auto_bin_max=4 with cross",
          group_max4.get_inst_coverage(), 18.75);
    check("covergroup auto_bin_max=8 with cross",
          group_max8.get_inst_coverage(), 8.8541666667);
    check("covergroup auto-bin type merge", group_max4.get_coverage(),
          2.5);

    cp_max4 = new(4);
    cp_max8 = new(8);
    cp_max4.sample(0);
    cp_max8.sample(0);
    check("coverpoint auto_bin_max=4", cp_max4.get_inst_coverage(), 25.0);
    check("coverpoint auto_bin_max=8", cp_max8.get_inst_coverage(), 12.5);
    check("coverpoint auto-bin type merge", cp_max4.get_coverage(),
          100.0 / 6.0);

    if (failures == 0) $display("PASSED");
    $finish(0);
  end
endmodule

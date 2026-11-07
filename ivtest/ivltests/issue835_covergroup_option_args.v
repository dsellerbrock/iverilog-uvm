module issue835_covergroup_option_args;
  bit [7:0] value;
  bit [7:0] cross_x, cross_y;

  covergroup at_least_group_cg(int limit);
    option.per_instance = 1;
    option.at_least = limit;
    cp: coverpoint value { bins chosen = {8'h05}; }
  endgroup

  covergroup at_least_point_cg(int limit);
    option.per_instance = 1;
    cp: coverpoint value {
      option.at_least = limit;
      bins chosen = {8'h05};
    }
  endgroup

  covergroup auto_bin_group_cg(int limit);
    option.per_instance = 1;
    option.auto_bin_max = limit;
    cp: coverpoint value;
  endgroup

  covergroup auto_bin_point_cg(int limit);
    option.per_instance = 1;
    cp: coverpoint value { option.auto_bin_max = limit; }
  endgroup

  covergroup at_least_merge_cg(int limit);
    option.at_least = limit;
    type_option.merge_instances = 1;
    cp: coverpoint value { bins chosen = {8'h05}; }
  endgroup

  covergroup auto_bin_merge_cg(int limit);
    option.auto_bin_max = limit;
    type_option.merge_instances = 1;
    cp: coverpoint value;
  endgroup

  covergroup auto_bin_cross_cg(int limit);
    option.auto_bin_max = limit;
    type_option.merge_instances = 1;
    xcp: coverpoint cross_x;
    ycp: coverpoint cross_y;
    xy: cross xcp, ycp;
  endgroup

  covergroup auto_bin_wide_cg(int limit)
      with function sample(bit [79:0] sample_value);
    option.per_instance = 1;
    option.auto_bin_max = limit;
    cp: coverpoint sample_value;
  endgroup

  at_least_group_cg ag2, ag3;
  at_least_point_cg ap2, ap3;
  auto_bin_group_cg bg2, bg4;
  auto_bin_point_cg bp2, bp4;
  at_least_merge_cg am2, am3;
  auto_bin_merge_cg bm2, bm4;
  auto_bin_cross_cg cx2, cx4;
  auto_bin_wide_cg wb2, wb4;

  initial begin
    ag2 = new(2); ag3 = new(3);
    ap2 = new(2); ap3 = new(3);
    bg2 = new(2); bg4 = new(4);
    bp2 = new(2); bp4 = new(4);
    am2 = new(2); am3 = new(3);
    bm2 = new(2); bm4 = new(4);
    cx2 = new(2); cx4 = new(4);
    wb2 = new(2); wb4 = new(4);

    value = 8'h05;
    repeat (2) begin
      ag2.sample(); ag3.sample();
      ap2.sample(); ap3.sample();
      am2.sample();
    end

    value = 8'h00;
    bg2.sample(); bg4.sample();
    bp2.sample(); bp4.sample();
    bm2.sample(); bm4.sample();
    value = 8'hc8;
    bm2.sample(); bm4.sample();

    cross_x = 0; cross_y = 0;
    cx2.sample();
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        cross_x = i * 64;
        cross_y = j * 64;
        cx4.sample();
      end
    end
    wb2.sample(80'h0);
    wb4.sample(80'h0);

    $display("AT_LEAST %0.0f %0.0f %0.0f %0.0f",
      ag2.get_inst_coverage(), ag3.get_inst_coverage(),
      ap2.get_inst_coverage(), ap3.get_inst_coverage());
    $display("AUTO_BIN_MAX %0.0f %0.0f %0.0f %0.0f",
      bg2.get_inst_coverage(), bg4.get_inst_coverage(),
      bp2.get_inst_coverage(), bp4.get_inst_coverage());
    $display("AT_LEAST_MERGE %0.2f", am2.get_coverage());
    $display("AUTO_BIN_MAX_MERGE %0.2f", bm2.get_coverage());
    $display("AUTO_BIN_CROSS %0.2f", cx2.get_coverage());
    $display("AUTO_BIN_MAX_WIDE %0.0f %0.0f",
      wb2.get_inst_coverage(), wb4.get_inst_coverage());

    if (ag2.get_inst_coverage() != 100.0
        || ag3.get_inst_coverage() != 0.0
        || ap2.get_inst_coverage() != 100.0
        || ap3.get_inst_coverage() != 0.0)
      $fatal(1, "constructor-dependent at_least was not applied per instance");
    if (bg2.get_inst_coverage() != 50.0
        || bg4.get_inst_coverage() != 25.0
        || bp2.get_inst_coverage() != 50.0
        || bp4.get_inst_coverage() != 25.0)
      $fatal(1, "constructor-dependent auto_bin_max was not applied per instance");
    if (am2.get_coverage() != 0.0)
      $fatal(1, "merged at_least did not use the maximum instance value");
    if (bm2.get_coverage() < 66.66 || bm2.get_coverage() > 66.67)
      $fatal(1, "merged auto-bin names did not retain instance ranges");
    if (cx2.get_coverage() < 83.88 || cx2.get_coverage() > 83.90)
      $fatal(1, "automatic cross bins did not use per-instance auto-bin ranges");
    if (wb2.get_inst_coverage() != 50.0
        || wb4.get_inst_coverage() != 25.0)
      $fatal(1, "wide auto_bin_max was not applied per instance");

    $display("PASSED");
  end
endmodule

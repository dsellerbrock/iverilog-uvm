module issue835_covergroup_ctor_options;
  bit [7:0] a, b;
  bit signed [7:0] s;

  covergroup cg_atleast(int al);
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    type_option.merge_instances = 1;
    option.at_least = al;
    cp: coverpoint a { bins hit = {5}; }
  endgroup

  covergroup cg_atleast_literal;
    option.per_instance = 1;
    option.at_least = 3;
    cp: coverpoint a { bins hit = {5}; }
  endgroup

  covergroup cp_atleast(int al);
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    type_option.merge_instances = 1;
    cp: coverpoint a { option.at_least = al; bins hit = {5}; }
  endgroup

  covergroup cp_atleast_literal;
    option.per_instance = 1;
    cp: coverpoint a { option.at_least = 3; bins hit = {5}; }
  endgroup

  covergroup cg_auto_max(int abm);
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    type_option.merge_instances = 1;
    option.auto_bin_max = abm;
    cp: coverpoint a;
  endgroup

  covergroup cp_auto_max(int abm);
    option.per_instance = 1;
    option.auto_bin_max = 64;
    cp: coverpoint a { option.auto_bin_max = abm; }
  endgroup

  covergroup literal_auto_max;
    option.per_instance = 1;
    option.auto_bin_max = 4;
    cp: coverpoint a;
  endgroup

  covergroup signed_auto_max(int abm);
    option.per_instance = 1;
    option.auto_bin_max = abm;
    cp: coverpoint s;
  endgroup

  covergroup cross_auto_max(int abm);
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    type_option.merge_instances = 1;
    option.auto_bin_max = abm;
    ca: coverpoint a;
    cb: coverpoint b;
    cab: cross ca, cb;
  endgroup

  cg_atleast at_arg2;
  cg_atleast at_arg3;
  cg_atleast_literal at_lit;
  cp_atleast cp_arg2;
  cp_atleast cp_arg3;
  cp_atleast_literal cp_at_lit;
  cg_auto_max auto4;
  cg_auto_max auto2;
  cp_auto_max cp_auto4;
  literal_auto_max auto_lit4;
  signed_auto_max auto_signed4;
  cross_auto_max cross4;
  cross_auto_max cross2;

  initial begin
    at_arg2 = new(2);
    at_arg3 = new(3);
    at_lit = new;
    cp_arg2 = new(2);
    cp_arg3 = new(3);
    cp_at_lit = new;

    a = 5;
    at_arg2.sample(); at_arg2.sample();
    at_lit.sample(); at_lit.sample();
    cp_arg2.sample(); cp_arg2.sample();
    cp_at_lit.sample(); cp_at_lit.sample();
    $display("ATL_GROUP_2 %0.2f %0.2f %0.2f",
             at_arg2.get_inst_coverage(), at_arg3.get_inst_coverage(),
             at_lit.get_inst_coverage());
    $display("ATL_POINT_2 %0.2f %0.2f %0.2f",
             cp_arg2.get_inst_coverage(), cp_arg3.get_inst_coverage(),
             cp_at_lit.get_inst_coverage());
    $display("ATL_TYPE_2 %0.2f %0.2f",
             at_arg2.get_coverage(), cp_arg2.get_coverage());

    at_arg2.sample(); at_arg3.sample(); at_arg3.sample(); at_arg3.sample();
    at_lit.sample();
    cp_arg2.sample(); cp_arg3.sample(); cp_arg3.sample(); cp_arg3.sample();
    cp_at_lit.sample();
    $display("ATL_GROUP_3 %0.2f %0.2f %0.2f",
             at_arg2.get_inst_coverage(), at_arg3.get_inst_coverage(),
             at_lit.get_inst_coverage());
    $display("ATL_POINT_3 %0.2f %0.2f %0.2f",
             cp_arg2.get_inst_coverage(), cp_arg3.get_inst_coverage(),
             cp_at_lit.get_inst_coverage());
    $display("ATL_TYPE_3 %0.2f %0.2f",
             at_arg2.get_coverage(), cp_arg2.get_coverage());

    auto4 = new(4);
    auto2 = new(2);
    cp_auto4 = new(4);
    auto_lit4 = new;
    auto_signed4 = new(4);
    a = 0;
    auto4.sample(); auto2.sample(); cp_auto4.sample(); auto_lit4.sample();
    $display("ABM_GROUP %0.2f %0.2f %0.2f",
             auto4.get_inst_coverage(), auto2.get_inst_coverage(),
             auto4.get_coverage());
    $display("ABM_POINT %0.2f %0.2f",
             cp_auto4.get_inst_coverage(), auto_lit4.get_inst_coverage());

    s = -128;
    auto_signed4.sample();
    $display("ABM_SIGNED %0.2f", auto_signed4.get_inst_coverage());

    cross4 = new(4);
    cross2 = new(2);
    a = 0; b = 0;
    cross4.sample(); cross2.sample();
    $display("ABM_CROSS %0.2f %0.2f %0.2f",
             cross4.cab.get_inst_coverage(), cross2.cab.get_inst_coverage(),
             cross4.cab.get_coverage());
  end
endmodule

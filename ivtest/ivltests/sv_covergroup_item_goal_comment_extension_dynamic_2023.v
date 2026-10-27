class dynamic_option_base;
  covergroup cg(int initial_goal, string initial_comment)
      with function sample(bit value);
    base_cp: coverpoint value;
  endgroup

  function new(int goal, string comment);
    cg = new(goal, comment);
  endfunction
endclass

class dynamic_option_both extends dynamic_option_base;
  bit ext_bit;
  covergroup extends cg;
    option.goal = initial_goal;
    option.comment = initial_comment;
    extra_cp: coverpoint ext_bit {
      option.goal = initial_goal;
      option.comment = initial_comment;
    }
    extra_cross: cross base_cp, extra_cp {
      option.goal = initial_goal;
      option.comment = initial_comment;
    }
  endgroup : cg

  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

class dynamic_option_goal_only extends dynamic_option_base;
  covergroup extends cg;
    option.goal = initial_goal;
  endgroup : cg

  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

class dynamic_option_comment_only extends dynamic_option_base;
  covergroup extends cg;
    option.comment = initial_comment;
  endgroup : cg

  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

class dynamic_option_item_only extends dynamic_option_base;
  bit ext_bit;
  covergroup extends cg;
    extra_cp: coverpoint ext_bit {
      option.goal = initial_goal;
      option.comment = initial_comment;
    }
  endgroup : cg

  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

class dynamic_option_group_base;
  covergroup cg(int initial_goal, string initial_comment)
      with function sample(bit value);
    option.goal = initial_goal;
    option.comment = initial_comment;
    base_cp: coverpoint value;
  endgroup

  function new(int goal, string comment);
    cg = new(goal, comment);
  endfunction
endclass

class dynamic_option_constant_override extends dynamic_option_group_base;
  covergroup extends cg;
    option.goal = 50;
  endgroup : cg

  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

class dynamic_option_goal_only_base;
  covergroup cg(int initial_goal, string initial_comment)
      with function sample(bit value);
    option.goal = initial_goal;
  endgroup

  function new(int goal, string comment);
    cg = new(goal, comment);
  endfunction
endclass

class dynamic_option_goal_constant_override extends dynamic_option_goal_only_base;
  covergroup extends cg;
    option.goal = 50;
  endgroup : cg

  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

class dynamic_option_noarg_base;
  covergroup cg(int initial_goal, string initial_comment)
      with function sample(bit value);
  endgroup

  function new;
    cg = new(5, "x");
  endfunction
endclass

class dynamic_option_implicit_derived extends dynamic_option_noarg_base;
  covergroup extends cg;
    option.goal = initial_goal;
    option.comment = initial_comment;
  endgroup : cg
endclass

class dynamic_option_chain_a;
  covergroup cg(int initial_goal, string initial_comment)
      with function sample(bit value);
  endgroup

  function new(int goal, string comment);
    cg = new(goal, comment);
  endfunction
endclass

class dynamic_option_chain_b extends dynamic_option_chain_a;
  covergroup extends cg;
    option.comment = initial_comment;
  endgroup : cg

  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

class dynamic_option_chain_c extends dynamic_option_chain_b;
  covergroup extends cg;
    option.goal = initial_goal;
  endgroup : cg

  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

class dynamic_option_layout_base;
  covergroup cg(int initial_goal, string initial_comment)
      with function sample(bit value);
    base_cp: coverpoint value;
  endgroup

  function new(int goal, string comment);
    cg = new(goal, comment);
  endfunction
endclass

class dynamic_option_layout_b extends dynamic_option_layout_base;
  bit b_value;
  covergroup extends cg;
    b_cp: coverpoint b_value;
    bx: cross base_cp, b_cp {
      option.goal = initial_goal;
    }
  endgroup : cg

  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

class dynamic_option_layout_c extends dynamic_option_layout_b;
  bit c_value;
  covergroup extends cg;
    cy: coverpoint c_value {
      option.comment = initial_comment;
    }
  endgroup : cg

  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

module sv_covergroup_item_goal_comment_extension_dynamic_2023;
  dynamic_option_both both;
  dynamic_option_goal_only goal_only;
  dynamic_option_comment_only comment_only;
  dynamic_option_item_only item_only;
  dynamic_option_constant_override constant_override;
  dynamic_option_goal_constant_override goal_constant_override;
  dynamic_option_implicit_derived implicit_derived;
  dynamic_option_chain_c chain;
  dynamic_option_layout_c layout;

  initial begin
    both = new(17, "both");
    goal_only = new(23, "unused");
    comment_only = new(31, "comment only");
    item_only = new(29, "item only");
    constant_override = new(37, "keep base comment");
    goal_constant_override = new(47, "unused");
    implicit_derived = new;
    chain = new(43, "three-level");
    layout = new(41, "layout-chain");
    if (both.cg.option.goal != 17 || both.cg.option.comment != "both")
      $fatal(1, "dynamic derived goal/comment were not initialized");
    if (both.cg.extra_cp.option.goal != 17
        || both.cg.extra_cp.option.comment != "both"
        || both.cg.extra_cross.option.goal != 17
        || both.cg.extra_cross.option.comment != "both")
      $fatal(1, "dynamic derived coverpoint/cross options were not initialized");
    if (goal_only.cg.option.goal != 23 || goal_only.cg.option.comment != "")
      $fatal(1, "dynamic derived goal-only initialization failed");
    if (comment_only.cg.option.goal != 100
        || comment_only.cg.option.comment != "comment only")
      $fatal(1, "dynamic derived comment-only initialization failed");
    if (item_only.cg.option.goal != 100 || item_only.cg.option.comment != ""
        || item_only.cg.extra_cp.option.goal != 29
        || item_only.cg.extra_cp.option.comment != "item only")
      $fatal(1, "dynamic derived item-only options were not initialized");
    if (constant_override.cg.option.goal != 50
        || constant_override.cg.option.comment != "keep base comment")
      $fatal(1, "constant derived option did not override dynamic base option");
    if (goal_constant_override.cg.option.goal != 50)
      $fatal(1, "constant goal did not override dynamic base goal");
    if (implicit_derived.cg.option.goal != 5
        || implicit_derived.cg.option.comment != "x")
      $fatal(1, "implicit derived constructor options were not initialized");
    if (chain.cg.option.goal != 43
        || chain.cg.option.comment != "three-level")
      $fatal(1, "three-level derived options were not initialized");
    if (layout.cg.option.goal != 100 || layout.cg.option.comment != ""
        || layout.cg.base_cp.option.goal != 100
        || layout.cg.base_cp.option.comment != ""
        || layout.cg.b_cp.option.goal != 100
        || layout.cg.b_cp.option.comment != ""
        || layout.cg.bx.option.goal != 41
        || layout.cg.bx.option.comment != ""
        || layout.cg.cy.option.goal != 100
        || layout.cg.cy.option.comment != "layout-chain")
      $fatal(1, "three-level extension item option slots were misaligned");
    $display("PASSED");
  end
endmodule

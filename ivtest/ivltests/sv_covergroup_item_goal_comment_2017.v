module sv_covergroup_item_goal_comment;
  class option_holder;
    covergroup embedded(int initial_goal, string initial_comment)
        with function sample(bit value);
      option.goal = initial_goal;
      option.comment = initial_comment;
      point: coverpoint value { bins zero = {0}; bins one = {1}; }
    endgroup
    function new(int g, string c);
      embedded = new(g, c);
    endfunction
  endclass

  covergroup configured(int initial_goal, string initial_comment)
      with function sample(bit a, bit b);
    option.goal = initial_goal;
    option.comment = initial_comment;
    option.per_instance = 1;
    option.weight = 2;
    cp_a: coverpoint a {
      bins zero = {0}; bins one = {1};
      option.goal = 11; option.comment = "declared-a";
      option.weight = 3; option.at_least = 2;
    }
    cp_b: coverpoint b {
      bins zero = {0}; bins one = {1};
      option.goal = initial_goal + 20; option.comment = initial_comment;
      option.weight = 4; option.at_least = 1;
    }
    cp_cross: cross cp_a, cp_b {
      option.goal = 13; option.comment = "declared-cross";
      option.weight = 5; option.at_least = 1;
    }
  endgroup

  covergroup group_only(int group_goal, string group_comment)
      with function sample(bit a, bit b);
    option.goal = group_goal;
    option.comment = group_comment;
    cp_a: coverpoint a { bins zero = {0}; }
    cp_b: coverpoint b { bins zero = {0}; }
    cp_cross: cross cp_a, cp_b;
  endgroup

  covergroup defaults with function sample(bit a, bit b);
    cp_a: coverpoint a { bins zero = {0}; }
    cp_b: coverpoint b { bins zero = {0}; }
    cp_cross: cross cp_a, cp_b;
  endgroup

  configured first, second;
  group_only group_only_item;
  defaults defaults_item;
  option_holder embedded_item;
  real before_type_coverage, before_instance_coverage;
  int old_weight, old_at_least;

  initial begin
    first = new(31, "first");
    second = new(41, "second");
    group_only_item = new(51, "group-only");
    defaults_item = new;
    embedded_item = new(61, "embedded");

    if (first.option.goal != 31 || first.option.comment != "first"
        || first.cp_a.option.goal != 11
        || first.cp_a.option.comment != "declared-a"
        || first.cp_b.option.goal != 51
        || first.cp_b.option.comment != "first"
        || first.cp_cross.option.goal != 13
        || first.cp_cross.option.comment != "declared-cross")
      $fatal(1, "declared goal/comment values were not initialized");
    if (defaults_item.option.goal != 100 || defaults_item.option.comment != ""
        || defaults_item.cp_a.option.goal != 100
        || defaults_item.cp_a.option.comment != ""
        || defaults_item.cp_cross.option.goal != 100
        || defaults_item.cp_cross.option.comment != "")
      $fatal(1, "default goal/comment values were not initialized");
    if (group_only_item.cp_a.option.goal != 100
        || group_only_item.cp_a.option.comment != ""
        || group_only_item.cp_cross.option.goal != 100
        || group_only_item.cp_cross.option.comment != "")
      $fatal(1, "covergroup goal/comment incorrectly defaulted to child options");
    if (embedded_item.embedded.option.goal != 61
        || embedded_item.embedded.option.comment != "embedded")
      $fatal(1, "embedded covergroup constructor options were not initialized");

    first.sample(0, 0);
    before_type_coverage = first.get_coverage();
    before_instance_coverage = first.get_inst_coverage();
    old_weight = first.cp_a.option.weight;
    old_at_least = first.cp_a.option.at_least;
    first.option.goal = 71;
    first.option.comment = "written-group";
    first.cp_a.option.goal = 72;
    first.cp_a.option.comment = "written-cp";
    first.cp_cross.option.goal = 73;
    first.cp_cross.option.comment = "written-cross";

    if (first.option.goal != 71 || first.option.comment != "written-group"
        || first.cp_a.option.goal != 72
        || first.cp_a.option.comment != "written-cp"
        || first.cp_cross.option.goal != 73
        || first.cp_cross.option.comment != "written-cross")
      $fatal(1, "procedural option writes did not read back");
    if (first.cp_b.option.goal != 51
        || first.cp_b.option.comment != "first")
      $fatal(1, "writing one coverpoint changed its sibling");
    if (second.option.goal != 41 || second.option.comment != "second"
        || second.cp_a.option.goal != 11
        || second.cp_a.option.comment != "declared-a"
        || second.cp_b.option.goal != 61
        || second.cp_b.option.comment != "second")
      $fatal(1, "covergroup option values leaked between instances");
    if (first.cp_a.option.weight != old_weight
        || first.cp_a.option.at_least != old_at_least)
      $fatal(1, "goal/comment writes changed weight or at_least");
    if (first.get_coverage() != before_type_coverage
        || first.get_inst_coverage() != before_instance_coverage)
      $fatal(1, "goal/comment writes changed coverage values");

    $display("PASSED");
  end
endmodule

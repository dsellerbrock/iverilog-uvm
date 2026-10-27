class goal_comment_base;
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

class goal_comment_derived extends goal_comment_base;
  bit extra_value;
  covergroup extends cg;
    option.goal = initial_goal;
    option.comment = initial_comment;
    extra_cp: coverpoint extra_value;
  endgroup : cg
  function new(int goal, string comment);
    super.new(goal, comment);
  endfunction
endclass

module sv_covergroup_item_goal_comment_extension_dynamic_fail;
  goal_comment_derived item;
  initial item = new(10, "base");
endmodule

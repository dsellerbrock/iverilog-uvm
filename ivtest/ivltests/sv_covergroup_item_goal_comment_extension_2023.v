class base_option_holder;
  covergroup cg with function sample(bit value);
    option.goal = 51;
    option.comment = "base";
    base_cp: coverpoint value {
      option.goal = 71;
      option.comment = "base-cp";
    }
  endgroup
  function new; cg = new; endfunction
endclass

class derived_option_holder extends base_option_holder;
  bit extra_value;
  covergroup extends cg;
    option.goal = 61;
    option.comment = "derived";
    extra_cp: coverpoint extra_value;
  endgroup : cg
  function new; super.new(); endfunction
endclass

module sv_covergroup_item_goal_comment_extension_2023;
  derived_option_holder item;
  initial begin
    item = new;
    if (item.cg.option.goal != 61 || item.cg.option.comment != "derived")
      $fatal(1, "derived covergroup options did not override base options");
    if (item.cg.base_cp.option.goal != 71
        || item.cg.base_cp.option.comment != "base-cp"
        || item.cg.extra_cp.option.goal != 100
        || item.cg.extra_cp.option.comment != "")
      $fatal(1, "covergroup-level goal/comment leaked into coverpoints");
    item.cg.option.goal = 62;
    item.cg.option.comment = "written-derived";
    if (item.cg.option.goal != 62 || item.cg.option.comment != "written-derived")
      $fatal(1, "derived covergroup option writes did not read back");
    $display("PASSED");
  end
endmodule

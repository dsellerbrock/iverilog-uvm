// IEEE 1800-2023 19.4.1/19.7.1: a replaced coverpoint keeps its instance
// option storage when read or written through an inherited class handle.
class coverpoint_slot_base;
  bit a, b;
  covergroup cg(int initial_goal);
    option.per_instance = 1;
    cp_a: coverpoint a {
      bins zero = {0}; bins one = {1}; option.weight = 0;
    }
    cp_b: coverpoint b {
      bins zero = {0}; bins one = {1}; option.goal = 22;
      option.comment = "base-cp_b"; option.weight = 0;
    }
    base_x: cross cp_a, cp_b {
      option.goal = 33; option.comment = "base-x"; option.weight = 1;
    }
  endgroup
  function new(int goal); cg = new(goal); endfunction
endclass

class coverpoint_slot_derived extends coverpoint_slot_base;
  covergroup extends cg;
    cp_b: coverpoint b {
      bins zero = {0}; bins one = {1}; option.goal = initial_goal;
      option.comment = "derived-cp_b"; option.weight = 0;
    }
  endgroup : cg
  function new(int goal); super.new(goal); endfunction
endclass

// The base cross creates b implicitly. The extension replaces that item with
// an explicit coverpoint while retaining the inherited cross's bin links.
class implicit_replace_base;
  bit a, b;
  covergroup cg;
    option.per_instance = 1;
    ab: cross a, b {
      option.goal = 33; option.comment = "base-ab"; option.weight = 1;
    }
  endgroup
  function new; cg = new; endfunction
endclass

class implicit_replace_derived extends implicit_replace_base;
  covergroup extends cg;
    b: coverpoint b {
      bins zero = {0}; bins one = {1}; option.goal = 222;
      option.comment = "derived-b"; option.weight = 0;
    }
  endgroup : cg
  function new; super.new; endfunction
endclass

module sv_covergroup_item_goal_comment_extension_coverpoint_slot_2023;
  coverpoint_slot_derived first, second;
  coverpoint_slot_base base_view, separate;
  implicit_replace_derived implicit_item;
  implicit_replace_base implicit_base_view;
  real coverage;

  initial begin
    first = new(55);
    second = new(77);
    base_view = first;
    if (base_view.cg.cp_b.option.goal != 55
        || first.cg.cp_b.option.goal != 55
        || base_view.cg.cp_b.option.comment != "derived-cp_b"
        || first.cg.cp_b.option.comment != "derived-cp_b")
      $fatal(1, "dynamic replacement coverpoint options disagree across handles");
    if (base_view.cg.base_x.option.goal != 33
        || base_view.cg.base_x.option.comment != "base-x")
      $fatal(1, "inherited cross options changed with coverpoint replacement");

    base_view.cg.cp_b.option.goal = 7;
    base_view.cg.cp_b.option.comment = "base-write";
    if (first.cg.cp_b.option.goal != 7
        || first.cg.cp_b.option.comment != "base-write")
      $fatal(1, "base-handle coverpoint writes were not shared");
    first.cg.cp_b.option.goal = 9;
    first.cg.cp_b.option.comment = "derived-write";
    if (base_view.cg.cp_b.option.goal != 9
        || base_view.cg.cp_b.option.comment != "derived-write")
      $fatal(1, "derived-handle coverpoint writes were not shared");
    if (second.cg.cp_b.option.goal != 77
        || second.cg.cp_b.option.comment != "derived-cp_b"
        || second.cg.cp_a.option.goal != 100)
      $fatal(1, "coverpoint option writes leaked to a sibling instance");

    first.a = 0; first.b = 0;
    base_view.cg.sample();
    coverage = first.cg.get_inst_coverage();
    if (coverage < 24.9 || coverage > 25.1)
      $fatal(1, "inherited cross did not sample through the replaced coverpoint: %0.1f",
             coverage);
    if (base_view.cg.base_x.option.goal != 33)
      $fatal(1, "coverpoint writes changed the base cross option");

    separate = new(99);
    if (separate.cg.cp_b.option.goal != 22
        || separate.cg.cp_b.option.comment != "base-cp_b"
        || separate.cg.base_x.option.goal != 33)
      $fatal(1, "derived coverpoint writes leaked to a base instance");

    implicit_item = new;
    implicit_base_view = implicit_item;
    if (implicit_base_view.cg.b.option.goal != 222
        || implicit_item.cg.b.option.goal != 222
        || implicit_base_view.cg.b.option.comment != "derived-b"
        || implicit_item.cg.b.option.comment != "derived-b")
      $fatal(1, "explicit coverpoint did not replace implicit option storage");
    if (implicit_base_view.cg.ab.option.goal != 33
        || implicit_base_view.cg.ab.option.comment != "base-ab")
      $fatal(1, "inherited cross options changed after implicit replacement");
    implicit_item.a = 0; implicit_item.b = 0;
    implicit_base_view.cg.sample();
    coverage = implicit_item.cg.get_inst_coverage();
    if (coverage < 37.4 || coverage > 37.6)
      $fatal(1, "inherited cross lost its implicit bin links: %0.1f", coverage);
    $display("PASSED");
  end
endmodule

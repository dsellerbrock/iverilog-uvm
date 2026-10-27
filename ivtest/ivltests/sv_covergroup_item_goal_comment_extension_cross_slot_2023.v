// IEEE 1800-2023 19.4.1/19.7.1: an item replacement retains its instance
// option identity across covergroup extensions and base-class handles.
class cross_slot_base;
  bit a, b, c;
  covergroup cg;
    option.per_instance = 1;
    ca: coverpoint a { bins zero = {0}; bins one = {1}; option.weight = 0; }
    cb: coverpoint b { bins zero = {0}; bins one = {1}; option.weight = 0; }
    cc: coverpoint c { bins zero = {0}; bins one = {1}; option.weight = 0; }
    x1: cross ca, cb {
      option.goal = 11; option.comment = "base-x1"; option.weight = 1;
    }
    x2: cross ca, cc {
      option.goal = 22; option.comment = "base-x2"; option.weight = 0;
    }
  endgroup
  function new; cg = new; endfunction
endclass

class cross_slot_mid extends cross_slot_base;
  covergroup extends cg;
    cb: coverpoint b {
      bins zero = {0}; bins one = {1}; option.weight = 0;
      option.goal = 55; option.comment = "mid-cb";
    }
    x1: cross ca, cb {
      option.goal = 111; option.comment = "mid-x1"; option.weight = 1;
    }
  endgroup : cg
  function new; super.new; endfunction
endclass

class cross_slot_leaf extends cross_slot_mid;
  covergroup extends cg;
    x1: cross ca, cb {
      option.goal = 211; option.comment = "leaf-x1"; option.weight = 1;
    }
    x3: cross cb, cc {
      option.goal = 33; option.comment = "leaf-x3"; option.weight = 0;
    }
  endgroup : cg
  function new; super.new; endfunction
endclass

// The base cross creates implicit coverpoints a/b; the extension reuses a
// and adds an implicit c through a new cross.
class implicit_slot_base;
  bit a, b, c;
  covergroup cg;
    ab: cross a, b { option.goal = 11; option.comment = "base-ab"; }
  endgroup
  function new; cg = new; endfunction
endclass

class implicit_slot_derived extends implicit_slot_base;
  covergroup extends cg;
    ac: cross a, c { option.goal = 22; option.comment = "derived-ac"; }
  endgroup : cg
  function new; super.new; endfunction
endclass

module sv_covergroup_item_goal_comment_extension_cross_slot_2023;
  cross_slot_base base_view, separate;
  cross_slot_mid middle_view;
  cross_slot_leaf item, sibling;
  implicit_slot_base implicit_base_view;
  implicit_slot_derived implicit_item;
  real coverage;

  initial begin
    item = new;
    middle_view = item;
    base_view = item;
    if (base_view.cg.x1.option.goal != 211
        || middle_view.cg.x1.option.goal != 211
        || item.cg.x1.option.goal != 211
        || base_view.cg.x1.option.comment != "leaf-x1"
        || middle_view.cg.x1.option.comment != "leaf-x1"
        || item.cg.x1.option.comment != "leaf-x1")
      $fatal(1, "three-level replacement cross options disagree");
    if (base_view.cg.x2.option.goal != 22
        || middle_view.cg.x2.option.goal != 22
        || item.cg.x2.option.goal != 22
        || base_view.cg.x2.option.comment != "base-x2")
      $fatal(1, "untouched inherited cross options changed");
    if (item.cg.x3.option.goal != 33
        || item.cg.x3.option.comment != "leaf-x3")
      $fatal(1, "new leaf cross options were not initialized");
    if (base_view.cg.cb.option.goal != 55
        || middle_view.cg.cb.option.goal != 55
        || item.cg.cb.option.goal != 55
        || base_view.cg.cb.option.comment != "mid-cb")
      $fatal(1, "replaced coverpoint options disagree across handles");

    base_view.cg.x1.option.goal = 301;
    base_view.cg.x1.option.comment = "base-write";
    if (middle_view.cg.x1.option.goal != 301
        || item.cg.x1.option.goal != 301
        || item.cg.x1.option.comment != "base-write")
      $fatal(1, "base-handle cross writes were not shared");
    middle_view.cg.x1.option.goal = 302;
    middle_view.cg.x1.option.comment = "middle-write";
    if (base_view.cg.x1.option.goal != 302
        || item.cg.x1.option.goal != 302
        || base_view.cg.x1.option.comment != "middle-write")
      $fatal(1, "middle-handle cross writes were not shared");
    if (item.cg.x2.option.goal != 22)
      $fatal(1, "writing a replacement cross changed its sibling");

    item.a = 0; item.b = 0; item.c = 0;
    base_view.cg.sample();
    coverage = item.cg.get_inst_coverage();
    if (coverage < 24.9 || coverage > 25.1)
      $fatal(1, "base cross did not sample through the replaced coverpoint: %0.1f",
             coverage);

    sibling = new;
    if (sibling.cg.x1.option.goal != 211
        || sibling.cg.x1.option.comment != "leaf-x1"
        || sibling.cg.x2.option.goal != 22)
      $fatal(1, "cross option writes leaked to a sibling instance");
    separate = new;
    if (separate.cg.x1.option.goal != 11
        || separate.cg.x1.option.comment != "base-x1"
        || separate.cg.x2.option.goal != 22)
      $fatal(1, "derived cross writes leaked to a base instance");

    implicit_item = new;
    implicit_base_view = implicit_item;
    if (implicit_base_view.cg.a.option.goal != 100
        || implicit_item.cg.a.option.goal != 100
        || implicit_base_view.cg.a.option.comment != ""
        || implicit_item.cg.a.option.comment != "")
      $fatal(1, "implicit inherited coverpoint options disagree across handles");
    if (implicit_base_view.cg.ab.option.goal != 11
        || implicit_item.cg.ab.option.goal != 11
        || implicit_base_view.cg.ab.option.comment != "base-ab")
      $fatal(1, "base cross options changed after implicit extension");
    if (implicit_item.cg.ac.option.goal != 22
        || implicit_item.cg.ac.option.comment != "derived-ac")
      $fatal(1, "new cross over implicit coverpoints was not initialized");
    implicit_base_view.cg.a.option.goal = 88;
    implicit_base_view.cg.a.option.comment = "base-a-write";
    implicit_base_view.cg.ab.option.goal = 12;
    implicit_base_view.cg.ab.option.comment = "base-ab-write";
    if (implicit_item.cg.a.option.goal != 88
        || implicit_item.cg.a.option.comment != "base-a-write"
        || implicit_item.cg.ab.option.goal != 12
        || implicit_item.cg.ab.option.comment != "base-ab-write")
      $fatal(1, "implicit item writes were not shared with derived handle");
    implicit_item.cg.a.option.goal = 89;
    implicit_item.cg.a.option.comment = "derived-a-write";
    if (implicit_base_view.cg.a.option.goal != 89
        || implicit_base_view.cg.a.option.comment != "derived-a-write")
      $fatal(1, "derived implicit-item writes were not shared with base handle");
    $display("PASSED");
  end
endmodule

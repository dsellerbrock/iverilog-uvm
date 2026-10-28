module sv_covergroup_item_goal_comment_extension_basehandle_2023;
  bit clk = 0;

class base_holder;
  bit a, b;
  covergroup cg @(posedge clk);
    option.goal = 41;
    option.comment = "base";
    cp_a: coverpoint a { option.goal = 42; option.comment = "base-a"; }
    cp_b: coverpoint b { option.goal = 43; option.comment = "base-b"; }
    cr_ab: cross cp_a, cp_b { option.goal = 44; option.comment = "base-ab"; }
  endgroup
  function new; cg = new; endfunction
endclass

class derived_holder extends base_holder;
  bit c;
  covergroup extends cg;
    option.goal = 61;
    option.comment = "derived";
    cp_c: coverpoint c { option.goal = 62; option.comment = "derived-c"; }
    cr_ac: cross cp_a, cp_c { option.goal = 63; option.comment = "derived-ac"; }
  endgroup : cg
endclass

class third_holder extends derived_holder;
  bit d;
  covergroup extends cg;
    option.goal = 71;
    option.comment = "third";
    cp_d: coverpoint d { option.goal = 72; option.comment = "third-d"; }
    cr_bd: cross cp_b, cp_d { option.goal = 73; option.comment = "third-bd"; }
  endgroup : cg
endclass

  base_holder bv, separate;
  derived_holder dv;
  derived_holder dv_base;
  third_holder tv;

  initial begin
    dv = new;
    bv = dv;
    if (bv.cg.option.goal != 61)
      $fatal(1, "base-handle derived group goal mismatch: %0d", bv.cg.option.goal);
    if (bv.cg.option.comment != "derived")
      $fatal(1, "base-handle derived group comment mismatch");
    if (bv.cg.cp_a.option.goal != 42)
      $fatal(1, "base-handle inherited coverpoint goal mismatch: %0d",
             bv.cg.cp_a.option.goal);
    if (bv.cg.cp_a.option.comment != "base-a")
      $fatal(1, "base-handle inherited coverpoint comment mismatch");
    if (bv.cg.cr_ab.option.goal != 44)
      $fatal(1, "base-handle inherited cross goal mismatch: %0d",
             bv.cg.cr_ab.option.goal);
    if (bv.cg.cr_ab.option.comment != "base-ab")
      $fatal(1, "base-handle inherited cross comment mismatch");

    tv = new;
    bv = tv;
    dv_base = tv;
    if (dv_base.cg.cp_c.option.goal != 62)
      $fatal(1, "base-handle inherited extension coverpoint goal mismatch: %0d",
             dv_base.cg.cp_c.option.goal);
    if (dv_base.cg.cp_c.option.comment != "derived-c")
      $fatal(1, "base-handle inherited extension coverpoint comment mismatch");
    if (dv_base.cg.cr_ac.option.goal != 63)
      $fatal(1, "base-handle inherited extension cross goal mismatch: %0d",
             dv_base.cg.cr_ac.option.goal);
    if (dv_base.cg.cr_ac.option.comment != "derived-ac")
      $fatal(1, "base-handle inherited extension cross comment mismatch");
    dv_base.cg.cp_c.option.goal = 84;
    dv_base.cg.cp_c.option.comment = "derived-c-write";
    dv_base.cg.cr_ac.option.goal = 85;
    dv_base.cg.cr_ac.option.comment = "derived-ac-write";
    if (tv.cg.cp_c.option.goal != 84
        || tv.cg.cp_c.option.comment != "derived-c-write"
        || tv.cg.cr_ac.option.goal != 85
        || tv.cg.cr_ac.option.comment != "derived-ac-write")
      $fatal(1, "base-handle extension-item writes were not visible in third-level handle");
    if (bv.cg.option.goal != 71)
      $fatal(1, "base-handle third-level group goal mismatch: %0d",
             bv.cg.option.goal);
    if (bv.cg.option.comment != "third")
      $fatal(1, "base-handle third-level group comment mismatch");
    if (bv.cg.cp_a.option.goal != 42)
      $fatal(1, "third-level inherited coverpoint goal mismatch: %0d",
             bv.cg.cp_a.option.goal);
    if (bv.cg.cp_a.option.comment != "base-a")
      $fatal(1, "third-level inherited coverpoint comment mismatch");
    if (bv.cg.cr_ab.option.goal != 44)
      $fatal(1, "third-level inherited cross goal mismatch: %0d",
             bv.cg.cr_ab.option.goal);
    if (bv.cg.cr_ab.option.comment != "base-ab")
      $fatal(1, "third-level inherited cross comment mismatch");

    bv.cg.option.goal = 81;
    bv.cg.option.comment = "base-write";
    bv.cg.cp_a.option.goal = 82;
    bv.cg.cp_a.option.comment = "base-cp-write";
    bv.cg.cr_ab.option.goal = 83;
    bv.cg.cr_ab.option.comment = "base-cross-write";
    if (tv.cg.option.goal != 81 || tv.cg.option.comment != "base-write"
        || tv.cg.cp_a.option.goal != 82 || tv.cg.cp_a.option.comment != "base-cp-write"
        || tv.cg.cr_ab.option.goal != 83 || tv.cg.cr_ab.option.comment != "base-cross-write")
      $fatal(1, "base-handle option writes were not visible through third-level handle");

    separate = new;
    if (separate.cg.option.goal != 41 || separate.cg.option.comment != "base"
        || separate.cg.cp_a.option.goal != 42 || separate.cg.cr_ab.option.goal != 44)
      $fatal(1, "base-handle writes leaked to a separate instance");
    $display("PASSED");
  end
endmodule

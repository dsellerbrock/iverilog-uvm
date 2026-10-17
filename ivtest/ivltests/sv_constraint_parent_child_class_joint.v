class joint_child;
  rand bit [1:0] x;
  constraint domain_c { x inside {2'd0, 2'd1}; }
endclass

class joint_parent;
  rand bit [1:0] y;
  rand joint_child child;
  function new; child = new; endfunction
  constraint relation_c {
    if (child.x == 0) y inside {2'd0, 2'd1, 2'd2};
    else y == 0;
  }
endclass

class cycle_base;
  randc bit [1:0] value;
  constraint domain_c { value inside {2'd0, 2'd1}; }
endclass

class cycle_derived extends cycle_base;
  rand bit [1:0] tag;
  constraint tag_c { tag == value; }
endclass

class rollback_parent_base;
  rand bit [1:0] value;
  rand cycle_base child;
  constraint link_c { value == child.value; }
endclass

class rollback_parent extends rollback_parent_base;
  bit impossible;
  constraint fail_c { if (impossible) child.value == 2'd2; }
endclass

class fixed_parent;
  rand bit [1:0] value;
  joint_child child;
  constraint link_c { value == child.x; }
endclass

module test;
  joint_parent item;
  joint_child original_child;
  int counts[2][4];
  rollback_parent_base root_a, root_b;
  rollback_parent parent_a, parent_b;
  cycle_derived child_a, child_b;
  fixed_parent fixed_item;
  bit [1:0] saved_parent, saved_child, saved_tag;

  initial begin
    item = new;
    original_child = item.child;
    item.srandom(32'h41800001);
    foreach (counts[i, j]) counts[i][j] = 0;
    repeat (1000) begin
      if (!item.randomize()) $fatal(1, "coupled parent/child randomize failed");
      if (item.child != original_child || item.child.x > 1)
        $fatal(1, "rand handle identity or child constraint changed");
      if (item.child.x == 0 && item.y < 3)
        counts[0][item.y]++;
      else if (item.child.x == 1 && item.y == 0)
        counts[1][0]++;
      else
        $fatal(1, "illegal parent/child tuple: child=%0d parent=%0d",
               item.child.x, item.y);
    end
    if (counts[0][0] < 170 || counts[0][0] > 330
        || counts[0][1] < 170 || counts[0][1] > 330
        || counts[0][2] < 170 || counts[0][2] > 330
        || counts[1][0] < 170 || counts[1][0] > 330)
      $fatal(1, "nonuniform coupled parent/child domain");

    parent_a = new; parent_b = new;
    child_a = new; child_b = new;
    root_a = parent_a; root_b = parent_b;
    parent_a.child = child_a; parent_b.child = child_b;
    parent_a.srandom(32'h41800002); parent_b.srandom(32'h41800002);
    child_a.srandom(32'h41800003); child_b.srandom(32'h41800003);
    repeat (2) begin
      if (!root_a.randomize() || !root_b.randomize())
        $fatal(1, "inherited parent/child randomize failed");
      if (root_a.value != child_a.value || child_a.tag != child_a.value
          || root_a.value != root_b.value || child_a.value != child_b.value
          || child_a.tag != child_b.tag)
        $fatal(1, "inherited coupled constraints disagree");
    end
    saved_parent = root_a.value;
    saved_child = child_a.value;
    saved_tag = child_a.tag;
    parent_a.impossible = 1;
    if (root_a.randomize()) $fatal(1, "unsatisfiable coupled solve succeeded");
    if (root_a.value != saved_parent || child_a.value != saved_child
        || child_a.tag != saved_tag || root_a.child != child_a)
      $fatal(1, "failed coupled solve changed object graph state");
    parent_a.impossible = 0;
    if (!root_a.randomize() || !root_b.randomize())
      $fatal(1, "retry after failed coupled solve failed");
    if (root_a.value != root_b.value || child_a.value != child_b.value
        || child_a.tag != child_b.tag)
      $fatal(1, "failed solve advanced child randc history");

    fixed_item = new;
    fixed_item.child = new;
    fixed_item.child.x = 2'd3;
    if (!fixed_item.randomize() || fixed_item.value != 2'd3
        || fixed_item.child.x != 2'd3)
      $fatal(1, "non-rand child was unexpectedly randomized");

    $display("PASS");
  end
endmodule

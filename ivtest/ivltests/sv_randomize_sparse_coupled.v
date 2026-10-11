class sparse_coupled;
  rand bit mode;
  rand bit [31:0] value;
  constraint legal {
    if (mode) value inside {32'd0, 32'd1};
    else value == 32'd0;
  }
endclass

class sparse_unsatisfiable;
  rand bit [15:0] left;
  rand bit [15:0] right;
  constraint impossible { left == 16'd0; left == 16'd1; right == 16'd0; }
endclass

class sparse_over_tuple_cap;
  rand bit selector;
  rand bit [31:0] value;
  rand bit [31:0] copy;
  constraint legal {
    if (selector) {
      value inside {[32'd1:32'd4096]};
      copy == value;
    } else {
      value == 32'd0;
      copy == 32'd0;
    }
  }
endclass

class sparse_functional_unequal;
  rand bit branch;
  rand bit [6:0] projected;
  rand bit [31:0] dependent;
  constraint legal {
    if (branch) projected inside {[7'd0:7'd31]};
    else projected inside {[7'd0:7'd95]};
    dependent == {25'd0, projected} + {31'd0, branch};
  }
endclass

module main;
  sparse_coupled item;
  sparse_unsatisfiable impossible;
  sparse_over_tuple_cap boundary;
  sparse_functional_unequal functional;
  integer count00 = 0;
  integer count10 = 0;
  integer count11 = 0;
  integer branch_count = 0;
  initial begin
    item = new;
    item.srandom(416);
    repeat (120) begin
      if (!item.randomize())
        $fatal(1, "sparse coupled randomize failed");
      if (!item.mode && item.value == 32'd0) count00++;
      else if (item.mode && item.value == 32'd0) count10++;
      else if (item.mode && item.value == 32'd1) count11++;
      else $fatal(1, "illegal sparse tuple");
    end
    if (count00 < 22 || count00 > 58
        || count10 < 22 || count10 > 58
        || count11 < 22 || count11 > 58)
      $fatal(1, "sparse legal tuples are biased: %0d,%0d,%0d",
             count00, count10, count11);

    impossible = new;
    impossible.left = 16'd3;
    impossible.right = 16'd4;
    if (impossible.randomize())
      $fatal(1, "unsatisfiable sparse randomize succeeded");
    if (impossible.left != 16'd3 || impossible.right != 16'd4)
      $fatal(1, "unsatisfiable sparse randomize changed object state");

    boundary = new;
    boundary.srandom(417);
    if (!boundary.randomize())
      $fatal(1, "over-cap sparse randomize failed");
    if (boundary.selector) begin
      if (boundary.value < 32'd1 || boundary.value > 32'd4096
          || boundary.copy != boundary.value)
        $fatal(1, "over-cap sparse result is outside its legal set");
    end else if (boundary.value != 32'd0 || boundary.copy != 32'd0)
      $fatal(1, "over-cap singleton result is outside its legal set");

    functional = new;
    functional.srandom(418);
    repeat (32) begin
      if (!functional.randomize())
        $fatal(1, "functional sparse randomize failed");
      if (functional.branch) begin
        if (functional.projected > 7'd31)
          $fatal(1, "functional sparse branch tuple is illegal");
        branch_count++;
      end else if (functional.projected > 7'd95)
        $fatal(1, "functional sparse branch tuple is illegal");
      if (functional.dependent
          != {25'd0, functional.projected} + {31'd0, functional.branch})
        $fatal(1, "functional sparse dependent value is wrong");
    end
    if (branch_count < 2 || branch_count > 14)
      $fatal(1, "functional sparse tuple distribution is biased: %0d/32",
             branch_count);
    $display("PASSED");
  end
endmodule

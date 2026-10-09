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
  rand bit [31:0] left;
  rand bit [31:0] right;
  constraint legal {
    left inside {[32'd0:32'd4096]};
    right == left;
  }
endclass

module main;
  sparse_coupled item;
  sparse_unsatisfiable impossible;
  sparse_over_tuple_cap boundary;
  integer count00 = 0;
  integer count10 = 0;
  integer count11 = 0;
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
    if (boundary.left > 32'd4096 || boundary.right != boundary.left)
      $fatal(1, "over-cap sparse result is outside its legal set");
    $display("PASSED");
  end
endmodule

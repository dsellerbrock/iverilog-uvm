class order_leaf;
  rand bit a;
endclass

class order_parent;
  rand bit [1:0] b;
  rand order_leaf child;
  bit impossible;

  function new;
    child = new;
  endfunction

  constraint relation_c { b inside {[0:(child.a ? 2'd3 : 2'd1)]}; }
  constraint order_c { solve child.a before b; }
  constraint fail_c {
    if (impossible) {
      child.a == 0;
      b == 3;
    }
  }
endclass

module test;
  order_parent item;
  int joint[2][4];
  int saved_a, saved_b;

  initial begin
    item = new;

    item.srandom(32'd1800);
    for (int sample = 0; sample < 2000; sample++) begin
      if (!item.randomize()) $fatal(1, "cross-object solve-before failed");
      joint[item.child.a][item.b]++;
    end

    // Solve-before makes child.a uniform first, then b uniform over the
    // values allowed by that choice: 500 samples per a=0 value and 250 per
    // a=1 value, within conservative six-sigma bounds.
    if (joint[0][0] < 425 || joint[0][0] > 575
        || joint[0][1] < 425 || joint[0][1] > 575
        || joint[1][0] < 190 || joint[1][0] > 310
        || joint[1][1] < 190 || joint[1][1] > 310
        || joint[1][2] < 190 || joint[1][2] > 310
        || joint[1][3] < 190 || joint[1][3] > 310)
      $fatal(1, "wrong ordered distribution: %0d %0d / %0d %0d %0d %0d",
             joint[0][0], joint[0][1], joint[1][0], joint[1][1],
             joint[1][2], joint[1][3]);

    saved_a = item.child.a;
    saved_b = item.b;
    item.impossible = 1;
    if (item.randomize()) $fatal(1, "unsatisfiable ordered solve succeeded");
    if (item.child.a != saved_a || item.b != saved_b)
      $fatal(1, "failed ordered solve changed a randomized value");

    $display("PASS");
  end
endmodule

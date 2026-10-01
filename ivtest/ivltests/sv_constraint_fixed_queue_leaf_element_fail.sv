// A fixed array of nonempty queue leaves must constrain every element.
class queue_leaf_element_item;
  rand bit q[2][$];
  constraint sizes { q[0].size() == 2; q[1].size() == 1; }
  constraint elements { foreach (q[i,j]) q[i][j] == 1; }
endclass

module test;
  queue_leaf_element_item c;
  initial begin
    c = new;
    if (!c.randomize()) $fatal(1, "randomize failed");
    if (c.q[0].size() != 2 || c.q[1].size() != 1)
      $fatal(1, "wrong queue sizes");
    foreach (c.q[i,j])
      if (c.q[i][j] !== 1) $fatal(1, "wrong queue element");
    $display("PASSED");
  end
endmodule

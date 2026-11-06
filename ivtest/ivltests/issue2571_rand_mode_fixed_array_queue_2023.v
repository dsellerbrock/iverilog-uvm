class fixed_array_queue_mode_item;
  rand bit [3:0] q[2][$];
endclass

module test;
  initial begin
    fixed_array_queue_mode_item item;
    item = new;
    item.q[0] = '{1, 2};
    item.q[1] = '{3};
    if (item.q[0][0].rand_mode() !== 1
        || item.q[0][1].rand_mode() !== 1
        || item.q[1][0].rand_mode() !== 1)
      $fatal(1, "queue elements should start active");
    item.q[0][0].rand_mode(0);
    if (item.q[0][0].rand_mode() !== 0
        || item.q[0][1].rand_mode() !== 1
        || item.q[1][0].rand_mode() !== 1)
      $fatal(1, "queue element mode query selected the wrong element");
    item.q[0][0].rand_mode(1);
    if (item.q[0][0].rand_mode() !== 1)
      $fatal(1, "queue element mode query did not observe re-enable");
    $display("ISSUE2571 rand_mode on fixed-array queue element PASS");
  end
endmodule
